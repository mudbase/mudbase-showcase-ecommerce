"""Thin synchronous wrapper around the real `mudbase_sdk` (urllib3-based, no
asyncio variant is published), plus small `asyncio.to_thread` adapters so
FastAPI's async handlers never block the event loop on a blocking HTTP call.

Two things below intentionally bypass the narrow generated *typed* wrapper
methods in favor of the SDK's own public low-level building blocks
(`ApiClient.param_serialize` + `ApiClient.call_api`), which every generated
method uses internally:

1. `register_with_role` — the generated `RegisterWithRoleRequest` model only
   declares `email`/`password`/`firstName`/`lastName`/`projectId`. The real
   `/api/auth/local/signup/{role}` endpoint's validator additionally requires
   `agreedToTerms` (see web/src/lib/mudbase.ts's identical note about the
   hand-rolled TS client) — a field the generated request model has no way to
   carry. Its generated response type is also declared `void` (no schema was
   captured for this operation), which would silently discard the token/user
   payload the endpoint actually returns.
2. `login_local_user` — the generated response's nested user model
   (`LoginLocalUser200ResponseUser`) only declares
   `id/email/firstName/lastName/role/emailVerified/twoFactorEnabled` — it has
   no `customRole` field, even though the real Multi-Role feature (added to
   the platform after this client was generated) returns one. We need
   `customRole` to gate the seller area, so we parse the raw response
   ourselves instead of trusting the incomplete typed model.

Both still go through `mudbase_sdk.ApiClient` — same configuration, host,
auth-header, and serialization machinery as every other call in this module.
"""

import json
from typing import Any

import mudbase_sdk
from mudbase_sdk.rest import ApiException  # type: ignore[attr-defined]  # matches the SDK's own generated doc examples

from app.config import get_settings


class MudbaseApiError(Exception):
    """Raised for any non-2xx Mudbase response, typed or raw."""

    def __init__(self, message: str, status_code: int, code: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.code = code


def _build_api_client(access_token: str | None = None) -> mudbase_sdk.ApiClient:
    settings = get_settings()
    configuration = mudbase_sdk.Configuration(host=settings.mudbase_url)
    if access_token:
        configuration.access_token = access_token
    return mudbase_sdk.ApiClient(configuration)


def _raw_json_call(
    api_client: mudbase_sdk.ApiClient,
    method: str,
    resource_path: str,
    path_params: dict[str, str] | None = None,
    body: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Issues a request via the SDK's own public serialize/call primitives and
    parses the JSON body ourselves. See module docstring for why."""
    serialized = api_client.param_serialize(
        method=method,
        resource_path=resource_path,
        path_params=path_params or {},
        query_params=[],
        header_params={"Content-Type": "application/json", "Accept": "application/json"},
        body=body,
        post_params=[],
        files={},
        auth_settings=[],
        collection_formats={},
    )
    response = api_client.call_api(*serialized)
    response.read()  # type: ignore[no-untyped-call]  # mudbase_sdk.rest.RESTResponse.read() ships without a type stub
    raw_text = response.data.decode("utf-8") if response.data else ""
    parsed: dict[str, Any] = json.loads(raw_text) if raw_text else {}

    if not (200 <= response.status < 300):
        message = parsed.get("error") or parsed.get("message") or f"Request failed ({response.status})"
        raise MudbaseApiError(message, response.status, parsed.get("code"))

    return parsed


def _wrap_api_exception(exc: ApiException) -> MudbaseApiError:
    body: dict[str, Any] = {}
    if exc.body:
        try:
            body = json.loads(exc.body)
        except (ValueError, TypeError):
            body = {}
    message = body.get("error") or body.get("message") or exc.reason or "Mudbase request failed"
    return MudbaseApiError(message, exc.status or 500, body.get("code"))


# ─── Auth ───────────────────────────────────────────────────────────────────


def register_with_role_sync(
    role: str,
    email: str,
    password: str,
    first_name: str,
    last_name: str,
    agreed_to_terms: bool,
) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client() as client:
        return _raw_json_call(
            client,
            "POST",
            "/api/auth/local/signup/{role}",
            path_params={"role": role},
            body={
                "email": email,
                "password": password,
                "firstName": first_name,
                "lastName": last_name,
                "projectId": settings.mudbase_project_id,
                "agreedToTerms": agreed_to_terms,
            },
        )


def login_sync(email: str, password: str) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client() as client:
        return _raw_json_call(
            client,
            "POST",
            "/api/auth/local/login",
            body={"email": email, "password": password, "projectId": settings.mudbase_project_id},
        )


def create_anonymous_session_sync() -> dict[str, Any]:
    """Guest browsing session (POST /api/auth/anonymous) — its JWT satisfies
    the `products` collection's `authenticated` read rule for a visitor who
    hasn't registered yet. Unlike register/login, `CreateAnonymousSession200Response`
    is a complete typed model for what we need (token/refreshToken/expiresIn;
    no customRole to lose since a guest never has one), so the generated
    typed method is used directly here."""
    settings = get_settings()
    with _build_api_client() as client:
        auth_api = mudbase_sdk.AuthenticationApi(client)
        try:
            response = auth_api.create_anonymous_session(
                create_anonymous_session_request=mudbase_sdk.CreateAnonymousSessionRequest(
                    projectId=settings.mudbase_project_id
                )
            )
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.to_dict()


def refresh_sync(refresh_token: str) -> dict[str, Any]:
    with _build_api_client() as client:
        return _raw_json_call(
            client,
            "POST",
            "/api/auth/refresh",
            body={"refreshToken": refresh_token},
        )


def logout_sync(access_token: str) -> None:
    with _build_api_client(access_token) as client:
        auth_api = mudbase_sdk.AuthenticationApi(client)
        try:
            auth_api.logout_local_user()
        except ApiException:
            # Best-effort: the caller always clears the local session cookie
            # regardless, so a dead/expired token on logout is not fatal.
            return


# ─── Collections (products / orders / carts) ───────────────────────────────


def list_data_sync(
    collection_id: str,
    *,
    filter_dict: dict[str, Any] | None = None,
    sort: str | None = None,
    page: int = 1,
    limit: int = 20,
    access_token: str | None = None,
) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        filter_str = json.dumps(filter_dict) if filter_dict else None
        try:
            response = api.list_data(
                settings.mudbase_project_id,
                collection_id,
                page=page,
                limit=limit,
                sort=sort,
                filter=filter_str,
            )
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        items = [item.to_dict() for item in (response.data or [])]
        pagination = response.pagination.to_dict() if response.pagination else None
        return {"data": items, "pagination": pagination}


def get_data_sync(collection_id: str, document_id: str, *, access_token: str | None = None) -> dict[str, Any] | None:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            response = api.get_data(settings.mudbase_project_id, collection_id, document_id)
        except ApiException as exc:
            if exc.status == 404:
                return None
            raise _wrap_api_exception(exc) from exc
        return response.data or {}


def create_data_sync(collection_id: str, body: dict[str, Any], *, access_token: str) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            response = api.create_data(settings.mudbase_project_id, collection_id, body)
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.data or {}


def update_data_sync(
    collection_id: str,
    document_id: str,
    body: dict[str, Any],
    *,
    access_token: str,
) -> dict[str, Any]:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            response = api.update_data(settings.mudbase_project_id, collection_id, document_id, body)
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
        return response.data or {}


def delete_data_sync(collection_id: str, document_id: str, *, access_token: str) -> None:
    settings = get_settings()
    with _build_api_client(access_token) as client:
        api = mudbase_sdk.DataApi(client)
        try:
            api.delete_data(settings.mudbase_project_id, collection_id, document_id)
        except ApiException as exc:
            raise _wrap_api_exception(exc) from exc
