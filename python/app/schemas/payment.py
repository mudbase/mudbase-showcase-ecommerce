"""Mirrors the PublicPaymentLink shape in web/src/lib/mudbase-server.ts."""

from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class PaymentLinkStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class PublicPaymentLink(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    token: str
    amount: str | None = None
    currency: str
    network: str
    address: str
    description: str | None = None
    redirect_url: str | None = Field(default=None, alias="redirectUrl")
    status: PaymentLinkStatus
    expires_at: str | None = Field(default=None, alias="expiresAt")
