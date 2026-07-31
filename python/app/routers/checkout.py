"""Checkout + payment status. Mirrors web/src/app/checkout/page.tsx,
web/src/app/checkout/[token]/page.tsx, and web/src/hooks/usePaymentLinkStatus.ts.

Unlike the SPA, nobody can reach this page with a non-empty cart while
signed out (carts require a `customer` session here — see routers/cart.py),
so there is no need to replicate the reference app's inline "register/login
without losing your cart" checkout step; a plain redirect-to-login suffices.
"""

import logging
from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from pydantic import ValidationError

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.order import ShippingAddress
from app.services import carts as carts_service
from app.services import orders as orders_service
from app.services import payments as payments_service
from app.services.payments import PaymentLinkFailed
from app.session import call_with_reauth, get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/checkout", response_class=HTMLResponse, response_model=None)
async def checkout_page(request: Request) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is None or not user.is_customer:
        set_flash(request, "Sign in to your account to check out.", "info")
        return RedirectResponse("/login?next=/checkout", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse("/login?next=/checkout", status_code=303)

    cart, _token = await call_with_reauth(request, token, lambda t: carts_service.get_cart(user.id, access_token=t))
    context = await build_base_context(request)
    context.update({"cart": cart, "errors": {}, "form_error": None})
    return templates.TemplateResponse(request=request, name="checkout.html", context=context)


@router.post("/checkout", response_class=HTMLResponse, response_model=None)
async def checkout_submit(
    request: Request,
    full_name: Annotated[str, Form()],
    line1: Annotated[str, Form()],
    line2: Annotated[str, Form()] = "",
    city: Annotated[str, Form()] = "",
    region: Annotated[str, Form()] = "",
    postal_code: Annotated[str, Form()] = "",
    country: Annotated[str, Form()] = "",
) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is None or not user.is_customer:
        return RedirectResponse("/login?next=/checkout", status_code=303)
    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse("/login?next=/checkout", status_code=303)

    cart, token = await call_with_reauth(request, token, lambda t: carts_service.get_cart(user.id, access_token=t))

    async def _rerender(errors: dict[str, str], form_error: str | None, status_code: int) -> HTMLResponse:
        context = await build_base_context(request)
        context.update({"cart": cart, "errors": errors, "form_error": form_error})
        return templates.TemplateResponse(
            request=request, name="checkout.html", context=context, status_code=status_code
        )

    if not cart or not cart.items:
        return await _rerender({}, "Your cart is empty — add something before checking out.", 400)

    try:
        address = ShippingAddress(
            fullName=full_name,
            line1=line1,
            line2=line2 or None,
            city=city,
            region=region,
            postalCode=postal_code,
            country=country,
        )
    except ValidationError as exc:
        errors = {str(err["loc"][0]): err["msg"] for err in exc.errors() if err["loc"]}
        return await _rerender(errors, None, 422)

    try:
        order, token = await call_with_reauth(
            request,
            token,
            lambda t: orders_service.create_order(
                user_id=user.id,
                items=cart.items,
                subtotal_cents=cart.subtotal_cents,
                shipping_address=address,
                access_token=t,
            ),
        )
    except MudbaseApiError as exc:
        logger.warning("Order creation failed for user %s: %s", user.id, exc.message)
        return await _rerender({}, f"Couldn't place your order: {exc.message}", 502)

    redirect_url = f"{request.base_url}orders/{order.id}"
    result = await payments_service.create_order_payment_link(
        order_id=order.id,
        amount_cents=cart.subtotal_cents,
        redirect_url=redirect_url,
    )

    if isinstance(result, PaymentLinkFailed):
        if result.reason == "kyc_required":
            try:
                await call_with_reauth(
                    request, token, lambda t: orders_service.revert_to_pending(order.id, access_token=t)
                )
            except MudbaseApiError as exc:
                logger.warning("Couldn't revert order %s to pending after KYC block: %s", order.id, exc.message)
        return await _rerender({}, result.message, 502)

    try:
        _order, token = await call_with_reauth(
            request, token, lambda t: orders_service.attach_payment_link(order.id, result.token, access_token=t)
        )
        await call_with_reauth(request, token, lambda t: carts_service.clear_cart(user.id, access_token=t))
    except MudbaseApiError as exc:
        # The payment link itself was already created successfully (it's the
        # part of this flow the customer actually depends on) — a failure to
        # persist the link token onto the order or clear the cart afterward
        # is logged, not surfaced, so a Mudbase hiccup here doesn't strand a
        # paying customer on an error page.
        logger.warning("Post-payment-link bookkeeping failed for order %s: %s", order.id, exc.message)
    return RedirectResponse(f"/checkout/{result.token}", status_code=303)


@router.get("/checkout/{token}", response_class=HTMLResponse, response_model=None)
async def checkout_payment_page(request: Request, token: str) -> HTMLResponse:
    try:
        link = await payments_service.get_public_payment_link(token)
        load_error: str | None = None
    except payments_service.PaymentLinkNotAvailable as exc:
        link = None
        load_error = str(exc)

    context = await build_base_context(request)
    context.update({"link": link, "load_error": load_error, "token": token})
    return templates.TemplateResponse(request=request, name="checkout_payment.html", context=context)


@router.get("/checkout/{token}/status", response_model=None)
async def checkout_payment_status(token: str) -> JSONResponse:
    """Backs the payment page's poller. Proxied server-side (rather than the
    browser calling cloud.mudbase.dev directly, as the reference SPA does)
    so this server-rendered app never has to assume a CORS allowlist entry
    for wherever it happens to be hosted."""
    try:
        link = await payments_service.get_public_payment_link(token)
    except payments_service.PaymentLinkNotAvailable as exc:
        return JSONResponse({"error": str(exc)}, status_code=502)
    return JSONResponse({"link": link.model_dump(mode="json", by_alias=True)})
