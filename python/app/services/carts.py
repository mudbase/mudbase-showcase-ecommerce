"""Carts collection: one document per user, `customer` role only, own-only.
No native upsert endpoint — every mutation re-reads the authoritative cart
first, then creates or updates, mirroring web/src/hooks/useCart.ts's
`persist` mutation and its documented duplicate-cart race-condition guard.
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.json_field import stringify_json_field
from app.mudbase_client import create_data_sync, list_data_sync, update_data_sync
from app.schemas.cart import Cart, CartItem


async def get_cart(user_id: str, *, access_token: str) -> Cart | None:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.carts_collection_id,
        filter_dict={"userId": user_id},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Cart.model_validate(docs[0]) if docs else None


async def _persist(user_id: str, items: list[CartItem], *, access_token: str) -> Cart:
    settings = get_settings()
    items_json = stringify_json_field([item.model_dump(by_alias=True) for item in items])
    existing = await get_cart(user_id, access_token=access_token)
    if existing:
        doc = await asyncio.to_thread(
            update_data_sync,
            settings.carts_collection_id,
            existing.id,
            {"itemsJson": items_json},
            access_token=access_token,
        )
    else:
        doc = await asyncio.to_thread(
            create_data_sync,
            settings.carts_collection_id,
            {"userId": user_id, "itemsJson": items_json},
            access_token=access_token,
        )
    return Cart.model_validate(doc)


async def add_item(
    user_id: str,
    *,
    product_id: str,
    name: str,
    price_cents: int,
    currency: str,
    image_url: str | None,
    quantity: int,
    access_token: str,
) -> Cart:
    cart = await get_cart(user_id, access_token=access_token)
    items = list(cart.items) if cart else []
    for index, item in enumerate(items):
        if item.product_id == product_id:
            items[index] = item.model_copy(update={"quantity": item.quantity + quantity})
            break
    else:
        items.append(
            CartItem(
                productId=product_id,
                name=name,
                priceCents=price_cents,
                currency=currency,
                imageUrl=image_url,
                quantity=quantity,
            )
        )
    return await _persist(user_id, items, access_token=access_token)


async def update_quantity(user_id: str, *, product_id: str, quantity: int, access_token: str) -> Cart:
    cart = await get_cart(user_id, access_token=access_token)
    items = list(cart.items) if cart else []
    if quantity <= 0:
        items = [item for item in items if item.product_id != product_id]
    else:
        items = [
            item.model_copy(update={"quantity": quantity}) if item.product_id == product_id else item
            for item in items
        ]
    return await _persist(user_id, items, access_token=access_token)


async def remove_item(user_id: str, *, product_id: str, access_token: str) -> Cart:
    cart = await get_cart(user_id, access_token=access_token)
    items = [item for item in (cart.items if cart else []) if item.product_id != product_id]
    return await _persist(user_id, items, access_token=access_token)


async def clear_cart(user_id: str, *, access_token: str) -> Cart:
    return await _persist(user_id, [], access_token=access_token)
