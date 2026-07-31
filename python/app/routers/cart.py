"""Cart page + mutations. Mirrors web/src/app/cart/page.tsx and
web/src/hooks/useCart.ts. Carts are `customer`-role-only in Mudbase, so —
unlike the reference SPA's localStorage guest cart — adding to cart here
always requires being signed in as a customer (see README "Known
limitations": no guest-cart bridging)."""

from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.services import carts as carts_service
from app.services import products as products_service
from app.session import call_with_reauth, get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()


async def _require_customer(request: Request) -> RedirectResponse | tuple[str, str]:
    """Returns (user_id, access_token) on success, or a redirect to sign in."""
    user = get_session_user(request)
    if user is None or not user.is_customer:
        set_flash(request, "Sign in to your account to use the cart.", "info")
        return RedirectResponse(f"/login?next={request.url.path}", status_code=303)
    token = await get_valid_access_token(request)
    if not token:
        set_flash(request, "Your session expired — please sign in again.", "info")
        return RedirectResponse("/login", status_code=303)
    return user.id, token


@router.get("/cart", response_class=HTMLResponse, response_model=None)
async def cart_page(request: Request) -> HTMLResponse | RedirectResponse:
    guard = await _require_customer(request)
    if isinstance(guard, RedirectResponse):
        return guard
    user_id, token = guard

    cart, _token = await call_with_reauth(request, token, lambda t: carts_service.get_cart(user_id, access_token=t))
    context = await build_base_context(request)
    context["cart"] = cart
    return templates.TemplateResponse(request=request, name="cart.html", context=context)


@router.post("/cart/add", response_model=None)
async def cart_add(
    request: Request,
    product_id: Annotated[str, Form()],
    quantity: Annotated[int, Form()] = 1,
) -> RedirectResponse:
    guard = await _require_customer(request)
    if isinstance(guard, RedirectResponse):
        return guard
    user_id, token = guard

    try:
        product, token = await call_with_reauth(
            request, token, lambda t: products_service.get_product_by_id(product_id, access_token=t)
        )
    except MudbaseApiError:
        product = None
    if product is None:
        set_flash(request, "That product is no longer available.", "error")
        return RedirectResponse("/", status_code=303)

    try:
        await call_with_reauth(
            request,
            token,
            lambda t: carts_service.add_item(
                user_id,
                product_id=product.id,
                name=product.name,
                price_cents=product.price_cents,
                currency=product.currency,
                image_url=product.image_url,
                quantity=max(1, quantity),
                access_token=t,
            ),
        )
        set_flash(request, f"Added {product.name} to your cart.", "success")
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't add that to your cart: {exc.message}", "error")

    return RedirectResponse(f"/products/{product.slug}", status_code=303)


@router.post("/cart/update", response_model=None)
async def cart_update(
    request: Request,
    product_id: Annotated[str, Form()],
    quantity: Annotated[int, Form()],
) -> RedirectResponse:
    guard = await _require_customer(request)
    if isinstance(guard, RedirectResponse):
        return guard
    user_id, token = guard

    try:
        await call_with_reauth(
            request,
            token,
            lambda t: carts_service.update_quantity(user_id, product_id=product_id, quantity=quantity, access_token=t),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update your cart: {exc.message}", "error")
    return RedirectResponse("/cart", status_code=303)


@router.post("/cart/remove", response_model=None)
async def cart_remove(request: Request, product_id: Annotated[str, Form()]) -> RedirectResponse:
    guard = await _require_customer(request)
    if isinstance(guard, RedirectResponse):
        return guard
    user_id, token = guard

    try:
        await call_with_reauth(
            request, token, lambda t: carts_service.remove_item(user_id, product_id=product_id, access_token=t)
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update your cart: {exc.message}", "error")
    return RedirectResponse("/cart", status_code=303)
