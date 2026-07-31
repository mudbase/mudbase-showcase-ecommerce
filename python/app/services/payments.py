"""Payment Links: creation is delegated to the already-deployed reference web
app's Route Handler (org owner/admin bearer token required, no API-key path —
see README "Known limitations"); status polling hits Mudbase's own public,
unauthenticated `GET /api/payment-links/:token`. Neither operation is covered
by the generated `mudbase_sdk` (no `PaymentLinksApi` in this SDK version), so
both go through `httpx` directly, matching how the reference Next.js app
itself calls them (plain `fetch`, not its own hand-rolled SDK client).
"""

from typing import Literal

import httpx
from pydantic import BaseModel

from app.config import get_settings
from app.schemas.payment import PublicPaymentLink

_REQUEST_TIMEOUT_SECONDS = 15.0


class PaymentLinkNotAvailable(Exception):
    pass


class PaymentLinkCreated(BaseModel):
    ok: Literal[True] = True
    token: str


class PaymentLinkFailed(BaseModel):
    ok: Literal[False] = False
    reason: Literal["kyc_required", "unknown"]
    message: str


PaymentLinkResult = PaymentLinkCreated | PaymentLinkFailed


async def create_order_payment_link(
    *,
    order_id: str,
    amount_cents: int,
    redirect_url: str,
) -> PaymentLinkResult:
    settings = get_settings()
    amount = f"{amount_cents / 100:.2f}"
    payload = {
        "orderId": order_id,
        "amount": amount,
        "currency": "USDC",
        "network": "POLYGON",
        "redirectUrl": redirect_url,
    }
    async with httpx.AsyncClient(timeout=_REQUEST_TIMEOUT_SECONDS) as client:
        try:
            response = await client.post(settings.pay_link_proxy_url, json=payload)
        except httpx.HTTPError as exc:
            return PaymentLinkFailed(reason="unknown", message=f"Couldn't reach the payments service: {exc}")

    body = response.json() if response.headers.get("content-type", "").startswith("application/json") else {}
    if response.status_code == 403:
        return PaymentLinkFailed(
            reason="kyc_required",
            message=body.get("error")
            or "This store's payments are still pending identity verification.",
        )
    if response.status_code >= 400:
        return PaymentLinkFailed(
            reason="unknown",
            message=body.get("error") or f"Couldn't start payment. Please try again. ({response.status_code})",
        )

    link = body.get("link") or {}
    token = link.get("token")
    if not token:
        return PaymentLinkFailed(reason="unknown", message="Payment link response was missing a token.")
    return PaymentLinkCreated(token=token)


async def get_public_payment_link(token: str) -> PublicPaymentLink:
    settings = get_settings()
    url = f"{settings.mudbase_url}/api/payment-links/{token}"
    async with httpx.AsyncClient(timeout=_REQUEST_TIMEOUT_SECONDS) as client:
        response = await client.get(url)
    if response.status_code >= 400:
        body = response.json() if response.headers.get("content-type", "").startswith("application/json") else {}
        raise PaymentLinkNotAvailable(body.get("error") or f"Payment link not available ({response.status_code})")
    body = response.json()
    return PublicPaymentLink.model_validate(body["link"])
