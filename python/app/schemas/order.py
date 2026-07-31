"""Mirrors web/src/types/order.ts, including the `orderStatus` (not `status`)
field-naming workaround described there:

Mudbase's server-side role-assignment guard blocks any collection write that
includes a literal `status` key, for every project end-user regardless of
role or collection permissions — the field name alone triggers it, with no
per-collection opt-out. The `orders` collection's status field is therefore
named `orderStatus`. Real platform constraint, not a typo.
"""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.json_field import parse_json_field
from app.utils import format_money, short_order_id


class OrderStatus(str, Enum):
    PENDING = "pending"
    AWAITING_PAYMENT = "awaiting_payment"
    PAID = "paid"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


ORDER_STATUS_LABELS: dict[OrderStatus, str] = {
    OrderStatus.PENDING: "Pending",
    OrderStatus.AWAITING_PAYMENT: "Awaiting payment",
    OrderStatus.PAID: "Paid",
    OrderStatus.SHIPPED: "Shipped",
    OrderStatus.DELIVERED: "Delivered",
    OrderStatus.CANCELLED: "Cancelled",
}

# Seller fulfillment queue's "advance to next stage" action — mirrors
# NEXT_STATUS in web/src/components/seller/SellerOrderQueue.tsx.
NEXT_ORDER_STATUS: dict[OrderStatus, OrderStatus] = {
    OrderStatus.PAID: OrderStatus.SHIPPED,
    OrderStatus.SHIPPED: OrderStatus.DELIVERED,
}


class OrderPaymentStatus(str, Enum):
    UNPAID = "unpaid"
    PAID = "paid"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class OrderLineItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    product_id: str = Field(alias="productId")
    name: str
    price_cents: int = Field(alias="priceCents")
    quantity: int

    @property
    def formatted_unit_price(self) -> str:
        return format_money(self.price_cents)

    @property
    def line_total_cents(self) -> int:
        return self.price_cents * self.quantity


class ShippingAddress(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    full_name: str = Field(alias="fullName", min_length=1)
    line1: str = Field(min_length=1)
    line2: str | None = None
    city: str = Field(min_length=1)
    region: str = Field(min_length=1)
    postal_code: str = Field(alias="postalCode", min_length=1)
    country: str = Field(min_length=1)


class Order(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    user_id: str = Field(alias="userId")
    items_json: str = Field(alias="itemsJson")
    subtotal_cents: int = Field(alias="subtotalCents")
    currency: str = "USD"
    order_status: OrderStatus = Field(alias="orderStatus")
    shipping_name: str | None = Field(default=None, alias="shippingName")
    shipping_address_json: str | None = Field(default=None, alias="shippingAddressJson")
    payment_link_token: str | None = Field(default=None, alias="paymentLinkToken")
    payment_status: OrderPaymentStatus = Field(alias="paymentStatus")
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")

    @property
    def items(self) -> list[OrderLineItem]:
        raw: list[dict[str, Any]] = parse_json_field(self.items_json, [])
        return [OrderLineItem.model_validate(item) for item in raw]

    @property
    def shipping_address(self) -> ShippingAddress | None:
        raw: dict[str, Any] | None = parse_json_field(self.shipping_address_json, None)
        return ShippingAddress.model_validate(raw) if raw else None

    @property
    def short_id(self) -> str:
        return short_order_id(self.id)

    @property
    def formatted_subtotal(self) -> str:
        return format_money(self.subtotal_cents, self.currency)

    @property
    def status_label(self) -> str:
        return ORDER_STATUS_LABELS[self.order_status]

    @property
    def next_status(self) -> OrderStatus | None:
        return NEXT_ORDER_STATUS.get(self.order_status)

    @property
    def needs_payment(self) -> bool:
        return bool(self.payment_link_token) and self.payment_status != OrderPaymentStatus.PAID
