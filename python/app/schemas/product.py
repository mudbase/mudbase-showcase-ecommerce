"""Mirrors web/src/types/product.ts. Field aliases match the raw Mudbase
document shape (camelCase, `_id`) so `Product.model_validate(doc)` works
directly off a `DataApi` response dict — no separate mapping layer."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.json_field import parse_json_field
from app.utils import discount_percent, format_money


class Product(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    name: str
    slug: str
    description: str | None = None
    price_cents: int = Field(alias="priceCents")
    compare_at_price_cents: int | None = Field(default=None, alias="compareAtPriceCents")
    currency: str = "USD"
    image_url: str | None = Field(default=None, alias="imageUrl")
    gallery_json: str | None = Field(default=None, alias="galleryJson")
    category: str | None = None
    stock: int = 0
    is_active: bool = Field(default=True, alias="isActive")
    seller_id: str | None = Field(default=None, alias="sellerId")
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")

    @property
    def gallery_urls(self) -> list[str]:
        return parse_json_field(self.gallery_json, [])

    @property
    def images(self) -> list[str]:
        urls = [self.image_url] if self.image_url else []
        return [*urls, *self.gallery_urls]

    @property
    def discount_percent(self) -> int | None:
        return discount_percent(self.price_cents, self.compare_at_price_cents)

    @property
    def formatted_price(self) -> str:
        return format_money(self.price_cents, self.currency)

    @property
    def formatted_compare_at_price(self) -> str | None:
        if self.compare_at_price_cents is None:
            return None
        return format_money(self.compare_at_price_cents, self.currency)

    @property
    def in_stock(self) -> bool:
        return self.stock > 0


class ProductFormValues(BaseModel):
    """Validated shape of the seller product create/edit form. Mirrors the
    zod schema in web/src/components/seller/ProductForm.tsx."""

    name: str = Field(min_length=1)
    description: str = ""
    price_cents: int = Field(ge=0)
    compare_at_price_cents: int | None = Field(default=None, ge=0)
    currency: str = Field(default="USD", min_length=1)
    image_url: str = ""
    gallery_urls: list[str] = Field(default_factory=list, max_length=8)
    category: str = ""
    stock: int = Field(ge=0)
    is_active: bool = True

    @field_validator("image_url")
    @classmethod
    def _validate_image_url(cls, value: str) -> str:
        if value and not (value.startswith("http://") or value.startswith("https://")):
            raise ValueError("Enter a valid image URL")
        return value

    @field_validator("gallery_urls")
    @classmethod
    def _validate_gallery_urls(cls, value: list[str]) -> list[str]:
        for url in value:
            if not (url.startswith("http://") or url.startswith("https://")):
                raise ValueError("Enter a valid image URL for every additional photo")
        return value

    @model_validator(mode="after")
    def _validate_compare_at_price(self) -> "ProductFormValues":
        if self.compare_at_price_cents is not None and self.compare_at_price_cents <= self.price_cents:
            raise ValueError("Compare-at price must be higher than the current price")
        return self
