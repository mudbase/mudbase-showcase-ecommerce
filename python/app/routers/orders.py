"""Order history + detail. Mirrors web/src/app/orders/page.tsx and
web/src/app/orders/[id]/page.tsx."""

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.services import orders as orders_service
from app.session import get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()


@router.get("/orders", response_class=HTMLResponse, response_model=None)
async def orders_list(request: Request) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is None:
        set_flash(request, "Sign in to view your orders.", "info")
        return RedirectResponse("/login?next=/orders", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse("/login?next=/orders", status_code=303)

    try:
        orders = await orders_service.list_orders_for_user(user.id, access_token=token)
        load_error: str | None = None
    except MudbaseApiError as exc:
        orders, load_error = [], f"Couldn't load your orders right now: {exc.message}"

    context = await build_base_context(request)
    context.update({"orders": orders, "load_error": load_error})
    return templates.TemplateResponse(request=request, name="orders_list.html", context=context)


@router.get("/orders/{order_id}", response_class=HTMLResponse, response_model=None)
async def order_detail(request: Request, order_id: str) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is None:
        set_flash(request, "Sign in to view this order.", "info")
        return RedirectResponse(f"/login?next=/orders/{order_id}", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse(f"/login?next=/orders/{order_id}", status_code=303)

    try:
        order = await orders_service.get_order(order_id, access_token=token)
    except MudbaseApiError:
        order = None

    context = await build_base_context(request)
    context["order"] = order
    status_code = 200 if order else 404
    return templates.TemplateResponse(
        request=request, name="order_detail.html", context=context, status_code=status_code
    )
