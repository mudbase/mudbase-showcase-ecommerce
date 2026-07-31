"""Orders collection: `customer` role creates/reads/updates own orders only
(ownership-conditioned server-side by Mudbase against the caller's JWT);
`seller` role reads/updates all orders unconditionally (fulfillment queue).
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.json_field import stringify_json_field
from app.mudbase_client import create_data_sync, get_data_sync, list_data_sync, update_data_sync
from app.schemas.cart import CartItem
from app.schemas.order import Order, OrderStatus, ShippingAddress

_SELLER_QUEUE_LIMIT = 100


async def create_order(
    *,
    user_id: str,
    items: list[CartItem],
    subtotal_cents: int,
    shipping_address: ShippingAddress,
    access_token: str,
) -> Order:
    settings = get_settings()
    line_items = [
        {"productId": item.product_id, "name": item.name, "priceCents": item.price_cents, "quantity": item.quantity}
        for item in items
    ]
    body: dict[str, Any] = {
        "userId": user_id,
        "itemsJson": stringify_json_field(line_items),
        "subtotalCents": subtotal_cents,
        "currency": "USD",
        "orderStatus": OrderStatus.AWAITING_PAYMENT.value,
        "shippingName": shipping_address.full_name,
        "shippingAddressJson": stringify_json_field(shipping_address.model_dump(by_alias=True)),
        "paymentStatus": "unpaid",
    }
    doc = await asyncio.to_thread(create_data_sync, settings.orders_collection_id, body, access_token=access_token)
    return Order.model_validate(doc)


async def attach_payment_link(order_id: str, token: str, *, access_token: str) -> Order:
    settings = get_settings()
    doc = await asyncio.to_thread(
        update_data_sync,
        settings.orders_collection_id,
        order_id,
        {"paymentLinkToken": token},
        access_token=access_token,
    )
    return Order.model_validate(doc)


async def revert_to_pending(order_id: str, *, access_token: str) -> Order:
    """Used when the payment-link proxy reports `kyc_required` — mirrors the
    reference checkout page.tsx's handling of that response."""
    settings = get_settings()
    doc = await asyncio.to_thread(
        update_data_sync,
        settings.orders_collection_id,
        order_id,
        {"orderStatus": OrderStatus.PENDING.value},
        access_token=access_token,
    )
    return Order.model_validate(doc)


async def get_order(order_id: str, *, access_token: str) -> Order | None:
    settings = get_settings()
    doc = await asyncio.to_thread(get_data_sync, settings.orders_collection_id, order_id, access_token=access_token)
    return Order.model_validate(doc) if doc else None


async def list_orders_for_user(user_id: str, *, access_token: str) -> list[Order]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.orders_collection_id,
        filter_dict={"userId": user_id},
        sort="-createdAt",
        access_token=access_token,
    )
    return [Order.model_validate(doc) for doc in result["data"]]


async def list_all_orders(*, access_token: str) -> list[Order]:
    """Seller fulfillment queue — no ownership filter, relies on the
    collection's unconditional `seller` role read permission."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.orders_collection_id,
        sort="-createdAt",
        limit=_SELLER_QUEUE_LIMIT,
        access_token=access_token,
    )
    return [Order.model_validate(doc) for doc in result["data"]]


async def advance_order_status(order_id: str, next_status: OrderStatus, *, access_token: str) -> Order:
    settings = get_settings()
    doc = await asyncio.to_thread(
        update_data_sync,
        settings.orders_collection_id,
        order_id,
        {"orderStatus": next_status.value},
        access_token=access_token,
    )
    return Order.model_validate(doc)
