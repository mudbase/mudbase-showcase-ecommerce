import "server-only"
import { MUDBASE_URL } from "./config"

/**
 * Server-only merchant client. Payment Link creation is an org owner/admin bearer-token endpoint
 * with no API-key path (see plan/build-plan.md "Payment Flow"), so this module holds a live
 * session for the org owner, obtained once during provisioning and refreshed on demand. It is
 * imported only from Route Handlers — `server-only` makes any accidental client import a build
 * error, and none of these values are ever sent to the browser.
 *
 * Refresh tokens rotate on every use (platform-enforced, single-use). A stateless serverless
 * function has nowhere durable to persist the rotated token between cold starts other than the
 * seed value in `MUDBASE_MERCHANT_REFRESH_TOKEN` - this module caches the rotated pair in module
 * scope so repeated calls on the same warm instance keep working, but a cold start always falls
 * back to the seed env var. If that seed has already been rotated away by a previous warm
 * instance, refresh fails and checkout surfaces a clear "payments temporarily unavailable"
 * error rather than crashing - see README "Known limitations" for the production-grade fix
 * (a durable token store), deliberately not added here to keep this demo Mudbase-only.
 */

interface MerchantSession {
  accessToken: string
  refreshToken: string
  expiresAtMs: number
}

let cached: MerchantSession | null = null

function decodeJwtExpiryMs(token: string): number {
  const payload = token.split(".")[1]
  if (!payload) return 0
  const json = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as { exp?: number }
  return (payload && json.exp ? json.exp * 1000 : 0)
}

async function refresh(refreshToken: string): Promise<MerchantSession> {
  const res = await fetch(`${MUDBASE_URL}/api/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken }),
  })
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string }
    throw new MerchantAuthError(body.error ?? `Merchant session refresh failed (${res.status})`, res.status)
  }
  const body = (await res.json()) as { token: string; refreshToken: string }
  return {
    accessToken: body.token,
    refreshToken: body.refreshToken,
    expiresAtMs: decodeJwtExpiryMs(body.token),
  }
}

export class MerchantAuthError extends Error {
  constructor(
    message: string,
    public statusCode: number,
  ) {
    super(message)
    this.name = "MerchantAuthError"
  }
}

export async function getMerchantAccessToken(): Promise<string> {
  const now = Date.now()
  const REFRESH_MARGIN_MS = 60_000

  if (cached && cached.expiresAtMs - REFRESH_MARGIN_MS > now) {
    return cached.accessToken
  }

  const seedRefreshToken = cached?.refreshToken ?? process.env.MUDBASE_MERCHANT_REFRESH_TOKEN
  if (!seedRefreshToken) {
    throw new MerchantAuthError("MUDBASE_MERCHANT_REFRESH_TOKEN is not configured", 500)
  }

  cached = await refresh(seedRefreshToken)
  return cached.accessToken
}

export type PaymentLinkStatus = "pending" | "paid" | "expired" | "cancelled"

export interface PaymentLink {
  _id: string
  token: string
  amount: string | null
  currency: string
  network: string
  address: string
  description: string | null
  redirectUrl: string | null
  status: PaymentLinkStatus
  paidTxHash: string | null
  paidAmount: string | null
  paidAt: string | null
  expiresAt: string | null
  createdAt: string
}

export type PublicPaymentLink = Pick<
  PaymentLink,
  "token" | "amount" | "currency" | "network" | "address" | "description" | "redirectUrl" | "status" | "expiresAt"
>

export interface CreatePaymentLinkParams {
  amount: string
  currency: string
  network: string
  description: string
  redirectUrl: string
}

export type CreatePaymentLinkResult =
  | { ok: true; link: PaymentLink }
  | { ok: false; reason: "kyc_required"; message: string }
  | { ok: false; reason: "merchant_auth_failed"; message: string }
  | { ok: false; reason: "unknown"; message: string }

export async function createOrderPaymentLink(params: CreatePaymentLinkParams): Promise<CreatePaymentLinkResult> {
  const orgId = process.env.MUDBASE_MERCHANT_ORG_ID
  if (!orgId) {
    return { ok: false, reason: "merchant_auth_failed", message: "MUDBASE_MERCHANT_ORG_ID is not configured" }
  }

  let accessToken: string
  try {
    accessToken = await getMerchantAccessToken()
  } catch (err) {
    return {
      ok: false,
      reason: "merchant_auth_failed",
      message: err instanceof Error ? err.message : "Merchant session unavailable",
    }
  }

  const res = await fetch(`${MUDBASE_URL}/api/orgs/${orgId}/payment-links`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(params),
  })

  if (res.status === 403) {
    const body = (await res.json().catch(() => ({}))) as { error?: string; code?: string }
    return {
      ok: false,
      reason: "kyc_required",
      message: body.error ?? "This store's identity verification is still pending — payments are not yet available.",
    }
  }

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string }
    return { ok: false, reason: "unknown", message: body.error ?? `Payment link creation failed (${res.status})` }
  }

  const body = (await res.json()) as { link: PaymentLink }
  return { ok: true, link: body.link }
}

export async function getPublicPaymentLink(token: string): Promise<PublicPaymentLink> {
  const res = await fetch(`${MUDBASE_URL}/api/payment-links/${token}`)
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string }
    throw new Error(body.error ?? `Payment link not available (${res.status})`)
  }
  const body = (await res.json()) as { link: PublicPaymentLink }
  return body.link
}
