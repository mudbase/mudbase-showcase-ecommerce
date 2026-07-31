"""Home / catalog + product detail. Mirrors web/src/app/page.tsx,
src/components/catalog/ProductGrid.tsx, and src/app/products/[slug]/page.tsx.
"""

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.services import products as products_service
from app.session import ensure_anonymous_session, get_valid_access_token
from app.templates_env import templates

router = APIRouter()


@router.get("/", response_class=HTMLResponse, response_model=None)
async def catalog_index(request: Request, category: str | None = None) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)

    try:
        # Fetched once, unfiltered, so the category pill list always shows every
        # category regardless of the current selection (rather than collapsing to
        # just the selected one, as it would if derived from an already-filtered list).
        all_active = await products_service.list_active_products(access_token=token)
        categories = sorted({p.category for p in all_active if p.category})
        products = [p for p in all_active if not category or p.category == category]
        load_error: str | None = None
    except MudbaseApiError as exc:
        products, categories = [], []
        load_error = f"Couldn't load the catalog right now: {exc.message}"

    context = await build_base_context(request)
    context.update(
        {
            "products": products,
            "categories": categories,
            "selected_category": category,
            "load_error": load_error,
        }
    )
    return templates.TemplateResponse(request=request, name="index.html", context=context)


@router.get("/products/{slug}", response_class=HTMLResponse, response_model=None)
async def product_detail(request: Request, slug: str) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)

    try:
        product = await products_service.get_product_by_slug(slug, access_token=token)
    except MudbaseApiError:
        product = None

    context = await build_base_context(request)
    context["product"] = product
    status_code = 200 if product and product.is_active else 404
    return templates.TemplateResponse(
        request=request, name="product_detail.html", context=context, status_code=status_code
    )
