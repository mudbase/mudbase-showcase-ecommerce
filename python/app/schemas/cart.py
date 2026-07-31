"""Mirrors web/src/types/cart.ts."""

from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.json_field import parse_json_field
from app.utils import format_money


class CartItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    product_id: str = Field(alias="productId")
    name: str
    price_cents: int = Field(alias="priceCents")
    currency: str = "USD"
    image_url: str | None = Field(default=None, alias="imageUrl")
    quantity: int = Field(ge=1)

    @property
    def formatted_unit_price(self) -> str:
        return format_money(self.price_cents, self.currency)

    @property
    def formatted_line_total(self) -> str:
        return format_money(self.price_cents * self.quantity, self.currency)


class Cart(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    user_id: str = Field(alias="userId")
    items_json: str = Field(alias="itemsJson", default="[]")

    @property
    def items(self) -> list[CartItem]:
        raw: list[dict[str, Any]] = parse_json_field(self.items_json, [])
        return [CartItem.model_validate(item) for item in raw]

    @property
    def subtotal_cents(self) -> int:
        return sum(item.price_cents * item.quantity for item in self.items)

    @property
    def item_count(self) -> int:
        return sum(item.quantity for item in self.items)

    @property
    def currency(self) -> str:
        items = self.items
        return items[0].currency if items else "USD"

    @property
    def formatted_subtotal(self) -> str:
        return format_money(self.subtotal_cents, self.currency)
