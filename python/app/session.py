"""Server-side session: the Mudbase JWT lives only in the signed, httpOnly
Starlette session cookie set up in main.py — it is never sent to browser JS,
matching the task's "never expose it to client JS" requirement (a deliberate
difference from the reference SPA, which necessarily holds the token in
memory/localStorage for its own direct browser-to-Mudbase calls).

Refresh-on-demand mirrors web/src/lib/mudbase-server.ts's margin-based
refresh, but per end-user session rather than a single shared merchant
session — every logged-in visitor here refreshes their own token.
"""

import asyncio
import logging
import time
from typing import Any

from fastapi import Request
from pydantic import BaseModel

from app.mudbase_client import MudbaseApiError, create_anonymous_session_sync, refresh_sync

logger = logging.getLogger(__name__)

_USER_KEY = "user"
_TOKEN_KEY = "token"
_REFRESH_KEY = "refresh_token"
_EXPIRES_KEY = "expires_at"
_FLASH_KEY = "flash"

_REFRESH_MARGIN_SECONDS: float = 60.0
_DEFAULT_EXPIRES_IN_SECONDS: float = 3600.0


class SessionUser(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    custom_role: str | None = None

    @property
    def is_customer(self) -> bool:
        return self.custom_role == "customer"

    @property
    def is_seller(self) -> bool:
        return self.custom_role == "seller"

    @property
    def display_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip() or self.email


def store_session(
    request: Request,
    *,
    user: dict[str, Any],
    token: str,
    refresh_token: str,
    expires_in: float | None,
) -> None:
    request.session[_USER_KEY] = {
        "id": user.get("id") or user.get("_id"),
        "email": user.get("email"),
        "first_name": user.get("firstName"),
        "last_name": user.get("lastName"),
        "custom_role": user.get("customRole"),
    }
    request.session[_TOKEN_KEY] = token
    request.session[_REFRESH_KEY] = refresh_token
    request.session[_EXPIRES_KEY] = time.time() + float(expires_in or _DEFAULT_EXPIRES_IN_SECONDS)


def clear_session(request: Request) -> None:
    request.session.clear()


def get_session_user(request: Request) -> SessionUser | None:
    data = request.session.get(_USER_KEY)
    if not data or not data.get("id"):
        return None
    return SessionUser(**data)


async def get_valid_access_token(request: Request) -> str | None:
    """Returns a live access token for the current session, refreshing it
    first if it is within `_REFRESH_MARGIN_SECONDS` of expiry. Clears the
    session and returns None if there is no session or refresh fails."""
    token: str | None = request.session.get(_TOKEN_KEY)
    if not token:
        return None

    expires_at = request.session.get(_EXPIRES_KEY, 0.0)
    if expires_at - _REFRESH_MARGIN_SECONDS > time.time():
        return token

    refresh_token = request.session.get(_REFRESH_KEY)
    if not refresh_token:
        clear_session(request)
        return None

    try:
        result = await asyncio.to_thread(refresh_sync, refresh_token)
    except MudbaseApiError as exc:
        logger.info("Session refresh failed, signing the visitor out: %s", exc.message)
        clear_session(request)
        return None

    new_token: str | None = result.get("token")
    new_refresh: str | None = result.get("refreshToken")
    if not new_token or not new_refresh:
        clear_session(request)
        return None

    request.session[_TOKEN_KEY] = new_token
    request.session[_REFRESH_KEY] = new_refresh
    request.session[_EXPIRES_KEY] = time.time() + float(result.get("expiresIn") or _DEFAULT_EXPIRES_IN_SECONDS)
    return new_token


async def ensure_anonymous_session(request: Request) -> None:
    """Establishes a lightweight anonymous Mudbase session for catalog
    browsing if the visitor has no session (real or anonymous) yet. Mirrors
    the reference SPA's `POST /api/auth/anonymous` on first load — the JWT it
    grants satisfies the `products` collection's `authenticated` read rule
    without requiring registration.

    This app does not bridge a guest cart into a real account afterward (see
    README "Known limitations") — the anonymous token is simply overwritten
    the moment someone registers or logs in via `store_session`. Best-effort:
    if the call fails, catalog pages render with an empty product list rather
    than raising, since a storefront that fails to load anything is worse
    than one that fails to load without a session.
    """
    if request.session.get(_TOKEN_KEY):
        return
    try:
        result = await asyncio.to_thread(create_anonymous_session_sync)
    except MudbaseApiError as exc:
        logger.warning("Anonymous session creation failed; catalog reads will run unauthenticated: %s", exc.message)
        return

    token = result.get("token")
    refresh_token = result.get("refreshToken") or result.get("refresh_token")
    if not token or not refresh_token:
        return

    request.session[_TOKEN_KEY] = token
    request.session[_REFRESH_KEY] = refresh_token
    request.session[_EXPIRES_KEY] = time.time() + float(
        result.get("expiresIn") or result.get("expires_in") or _DEFAULT_EXPIRES_IN_SECONDS
    )


def set_flash(request: Request, message: str, category: str = "info") -> None:
    request.session[_FLASH_KEY] = {"message": message, "category": category}


def pop_flash(request: Request) -> dict[str, str] | None:
    flash: dict[str, str] | None = request.session.pop(_FLASH_KEY, None)
    return flash
