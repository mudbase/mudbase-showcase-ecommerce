"""Products collection: read is open to any `authenticated` session
(customer, seller, or the anonymous guest session `session.ensure_anonymous_
session` establishes on first visit), write is `seller`-role only.
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.json_field import stringify_json_field
from app.mudbase_client import create_data_sync, delete_data_sync, get_data_sync, list_data_sync, update_data_sync
from app.schemas.product import Product, ProductFormValues
from app.utils import random_slug_suffix, slugify

_CATALOG_LIMIT = 60
_SELLER_LIMIT = 100


async def list_active_products(category: str | None = None, *, access_token: str | None = None) -> list[Product]:
    settings = get_settings()
    filter_dict: dict[str, Any] = {"isActive": True}
    if category:
        filter_dict["category"] = category
    result = await asyncio.to_thread(
        list_data_sync,
        settings.products_collection_id,
        filter_dict=filter_dict,
        sort="-createdAt",
        limit=_CATALOG_LIMIT,
        access_token=access_token,
    )
    return [Product.model_validate(doc) for doc in result["data"]]


async def get_product_by_slug(slug: str, *, access_token: str | None = None) -> Product | None:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.products_collection_id,
        filter_dict={"slug": slug},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Product.model_validate(docs[0]) if docs else None


async def get_product_by_id(product_id: str, *, access_token: str | None = None) -> Product | None:
    """Any `authenticated` read is fine here — used both by the seller edit
    form and by cart/checkout to snapshot current name/price/image into a
    line item, not just by seller-gated routes."""
    settings = get_settings()
    doc = await asyncio.to_thread(get_data_sync, settings.products_collection_id, product_id, access_token=access_token)
    return Product.model_validate(doc) if doc else None


async def list_seller_products(access_token: str) -> list[Product]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.products_collection_id,
        sort="-createdAt",
        limit=_SELLER_LIMIT,
        access_token=access_token,
    )
    return [Product.model_validate(doc) for doc in result["data"]]


def _form_values_to_body(values: ProductFormValues) -> dict[str, Any]:
    body: dict[str, Any] = {
        "name": values.name,
        "description": values.description,
        "priceCents": values.price_cents,
        "currency": values.currency,
        "imageUrl": values.image_url or None,
        "galleryJson": stringify_json_field(values.gallery_urls),
        "category": values.category or None,
        "stock": values.stock,
        "isActive": values.is_active,
    }
    if values.compare_at_price_cents is not None:
        body["compareAtPriceCents"] = values.compare_at_price_cents
    return body


async def create_product(values: ProductFormValues, *, seller_id: str, access_token: str) -> Product:
    settings = get_settings()
    body = _form_values_to_body(values)
    body["slug"] = f"{slugify(values.name)}-{random_slug_suffix()}"
    body["sellerId"] = seller_id
    doc = await asyncio.to_thread(create_data_sync, settings.products_collection_id, body, access_token=access_token)
    return Product.model_validate(doc)


async def update_product(product_id: str, values: ProductFormValues, *, access_token: str) -> Product:
    settings = get_settings()
    body = _form_values_to_body(values)
    doc = await asyncio.to_thread(
        update_data_sync, settings.products_collection_id, product_id, body, access_token=access_token
    )
    return Product.model_validate(doc)


async def delete_product(product_id: str, *, access_token: str) -> None:
    settings = get_settings()
    await asyncio.to_thread(delete_data_sync, settings.products_collection_id, product_id, access_token=access_token)
