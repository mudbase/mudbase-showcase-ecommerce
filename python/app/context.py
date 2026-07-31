"""Per-request template context shared across every page: current user (if
any), the header cart-badge count, and a one-shot flash message."""

from typing import Any

from fastapi import Request

from app.services import carts as carts_service
from app.session import get_session_user, get_valid_access_token, pop_flash


async def build_base_context(request: Request) -> dict[str, Any]:
    user = get_session_user(request)
    cart_count = 0

    if user is not None and user.is_customer:
        token = await get_valid_access_token(request)
        if token:
            cart = await carts_service.get_cart(user.id, access_token=token)
            cart_count = cart.item_count if cart else 0

    return {
        "current_user": user,
        "cart_count": cart_count,
        "flash": pop_flash(request),
    }
