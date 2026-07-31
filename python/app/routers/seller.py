"""Seller dashboard: order fulfillment queue + product CRUD. Mirrors
web/src/app/seller/page.tsx, web/src/components/seller/SellerOrderQueue.tsx,
web/src/components/seller/ProductTable.tsx, and the new/edit product pages.
Gated on `customRole == "seller"`, matching SellerGuard.tsx — a redirect to
"/", not a 403 page, exactly like the reference app.
"""

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError
from starlette.datastructures import FormData

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.product import ProductFormValues
from app.services import orders as orders_service
from app.services import products as products_service
from app.session import SessionUser, get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()


async def _require_seller(request: Request) -> RedirectResponse | tuple[SessionUser, str]:
    user = get_session_user(request)
    if user is None or not user.is_seller:
        return RedirectResponse("/", status_code=303)
    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse("/login", status_code=303)
    return user, token


@router.get("/seller", response_class=HTMLResponse, response_model=None)
async def seller_dashboard(request: Request) -> HTMLResponse | RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard
    _user, token = guard

    try:
        orders = await orders_service.list_all_orders(access_token=token)
        orders_error: str | None = None
    except MudbaseApiError as exc:
        orders, orders_error = [], f"Couldn't load orders: {exc.message}"

    try:
        products = await products_service.list_seller_products(token)
        products_error: str | None = None
    except MudbaseApiError as exc:
        products, products_error = [], f"Couldn't load products: {exc.message}"

    context = await build_base_context(request)
    context.update(
        {
            "orders": orders,
            "orders_error": orders_error,
            "products": products,
            "products_error": products_error,
        }
    )
    return templates.TemplateResponse(request=request, name="seller_dashboard.html", context=context)


@router.post("/seller/orders/{order_id}/advance", response_model=None)
async def seller_advance_order(request: Request, order_id: str) -> RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard
    _user, token = guard

    try:
        order = await orders_service.get_order(order_id, access_token=token)
        if order and order.next_status:
            await orders_service.advance_order_status(order_id, order.next_status, access_token=token)
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update that order: {exc.message}", "error")

    return RedirectResponse("/seller", status_code=303)


@router.get("/seller/products/new", response_class=HTMLResponse, response_model=None)
async def new_product_page(request: Request) -> HTMLResponse | RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard

    context = await build_base_context(request)
    context.update({"product": None, "errors": {}, "form_error": None})
    return templates.TemplateResponse(request=request, name="seller_product_form.html", context=context)


@router.get("/seller/products/{product_id}/edit", response_class=HTMLResponse, response_model=None)
async def edit_product_page(request: Request, product_id: str) -> HTMLResponse | RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard
    _user, token = guard

    product = await products_service.get_product_by_id(product_id, access_token=token)
    if product is None:
        set_flash(request, "That product couldn't be found.", "error")
        return RedirectResponse("/seller", status_code=303)

    context = await build_base_context(request)
    context.update({"product": product, "errors": {}, "form_error": None})
    return templates.TemplateResponse(request=request, name="seller_product_form.html", context=context)


def _form_to_str_dict(form: FormData) -> dict[str, str]:
    """Every field in this form is plain text (no file uploads — see README
    "Known limitations" re: Mudbase file uploads requiring an org role no
    seller account has), so this narrows FormData's `str | UploadFile`
    values down to the `str` dict the rest of this module expects."""
    return {key: value for key, value in form.items() if isinstance(value, str)}


def _gallery_urls_from_form(form: FormData) -> list[str]:
    """Same `str | UploadFile` narrowing as `_form_to_str_dict`, for the
    repeatable `gallery_url` field."""
    return [value.strip() for value in form.getlist("gallery_url") if isinstance(value, str) and value.strip()]


def _parse_product_form(form: dict[str, str], gallery_urls: list[str]) -> ProductFormValues:
    compare_at_raw = form.get("compare_at_price_cents", "").strip()
    return ProductFormValues(
        name=form.get("name", ""),
        description=form.get("description", ""),
        price_cents=int(form.get("price_cents") or 0),
        compare_at_price_cents=int(compare_at_raw) if compare_at_raw else None,
        currency=form.get("currency") or "USD",
        image_url=form.get("image_url", ""),
        gallery_urls=gallery_urls,
        category=form.get("category", ""),
        stock=int(form.get("stock") or 0),
        is_active=form.get("is_active") == "on",
    )


@router.post("/seller/products/new", response_class=HTMLResponse, response_model=None)
async def create_product_submit(request: Request) -> HTMLResponse | RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard
    user, token = guard

    raw_form = await request.form()
    gallery_urls = _gallery_urls_from_form(raw_form)
    try:
        values = _parse_product_form(_form_to_str_dict(raw_form), gallery_urls)
    except (ValidationError, ValueError) as exc:
        context = await build_base_context(request)
        context.update({"product": None, "errors": _form_errors(exc), "form_error": None})
        return templates.TemplateResponse(
            request=request, name="seller_product_form.html", context=context, status_code=422
        )

    try:
        await products_service.create_product(values, seller_id=user.id, access_token=token)
    except MudbaseApiError as exc:
        context = await build_base_context(request)
        context.update({"product": None, "errors": {}, "form_error": exc.message})
        return templates.TemplateResponse(
            request=request, name="seller_product_form.html", context=context, status_code=400
        )

    set_flash(request, f"{values.name} was added to the catalog.", "success")
    return RedirectResponse("/seller", status_code=303)


@router.post("/seller/products/{product_id}/edit", response_class=HTMLResponse, response_model=None)
async def update_product_submit(request: Request, product_id: str) -> HTMLResponse | RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard
    _user, token = guard

    raw_form = await request.form()
    gallery_urls = _gallery_urls_from_form(raw_form)
    try:
        values = _parse_product_form(_form_to_str_dict(raw_form), gallery_urls)
    except (ValidationError, ValueError) as exc:
        product = await products_service.get_product_by_id(product_id, access_token=token)
        context = await build_base_context(request)
        context.update({"product": product, "errors": _form_errors(exc), "form_error": None})
        return templates.TemplateResponse(
            request=request, name="seller_product_form.html", context=context, status_code=422
        )

    try:
        await products_service.update_product(product_id, values, access_token=token)
    except MudbaseApiError as exc:
        product = await products_service.get_product_by_id(product_id, access_token=token)
        context = await build_base_context(request)
        context.update({"product": product, "errors": {}, "form_error": exc.message})
        return templates.TemplateResponse(
            request=request, name="seller_product_form.html", context=context, status_code=400
        )

    set_flash(request, f"{values.name} was updated.", "success")
    return RedirectResponse("/seller", status_code=303)


@router.post("/seller/products/{product_id}/delete", response_model=None)
async def delete_product_submit(request: Request, product_id: str) -> RedirectResponse:
    guard = await _require_seller(request)
    if isinstance(guard, RedirectResponse):
        return guard
    _user, token = guard

    try:
        await products_service.delete_product(product_id, access_token=token)
        set_flash(request, "Product deleted.", "success")
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't delete that product: {exc.message}", "error")

    return RedirectResponse("/seller", status_code=303)


def _form_errors(exc: Exception) -> dict[str, str]:
    if isinstance(exc, ValidationError):
        return {str(err["loc"][0]) if err["loc"] else "form": err["msg"] for err in exc.errors()}
    return {"form": str(exc)}
