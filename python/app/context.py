"""Per-request template context shared across every page: current user (if
any), the header cart-badge count, and a one-shot flash message."""

import logging
from typing import Any

from fastapi import Request

from app.mudbase_client import MudbaseApiError
from app.services import carts as carts_service
from app.session import call_with_reauth, get_session_user, get_valid_access_token, pop_flash

logger = logging.getLogger(__name__)


async def build_base_context(request: Request) -> dict[str, Any]:
    user = get_session_user(request)
    cart_count = 0

    if user is not None and user.is_customer:
        token = await get_valid_access_token(request)
        if token:
            try:
                cart, _token = await call_with_reauth(
                    request, token, lambda t: carts_service.get_cart(user.id, access_token=t)
                )
                cart_count = cart.item_count if cart else 0
            except MudbaseApiError as exc:
                # The cart badge is decoration on every page, not the page's
                # purpose — a Mudbase hiccup here shouldn't 500 the whole
                # request. Render with a 0 count instead.
                logger.warning("Couldn't load cart badge count for user %s: %s", user.id, exc.message)

    return {
        "current_user": user,
        "cart_count": cart_count,
        "flash": pop_flash(request),
    }
