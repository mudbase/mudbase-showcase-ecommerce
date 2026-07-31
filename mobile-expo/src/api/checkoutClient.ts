import { CHECKOUT_PROXY_URL } from "@/config/env";
import { createPaymentLinkResponseSchema, paymentLinkErrorSchema } from "./schemas";

export interface CreatePaymentLinkParams {
  orderId: string;
  amount: string;
  currency: string;
  network: string;
  redirectUrl: string;
}

export type CreatePaymentLinkResult =
  | { ok: true; token: string }
  | { ok: false; reason: "kyc_required"; message: string }
  | { ok: false; reason: "other"; message: string };

/**
 * Creating a Mudbase Payment Link requires an org owner/admin bearer token —
 * there is no API-key path for it, and a project end-user's token (what this
 * app holds) can never carry an org role. That credential must never ship
 * inside a mobile binary, so this app never calls Mudbase's payment-links
 * endpoint directly. Instead it calls the already-deployed web reference
 * app's own Route Handler (web/src/app/api/checkout/pay-link/route.ts), which
 * holds that credential server-side and creates the link on this order's
 * behalf. Everything else in this app (auth, products, cart, orders) talks
 * straight to cloud.mudbase.dev.
 */
export async function createOrderPaymentLink(params: CreatePaymentLinkParams): Promise<CreatePaymentLinkResult> {
  const res = await fetch(CHECKOUT_PROXY_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(params),
  });

  if (!res.ok) {
    const body = paymentLinkErrorSchema.parse(await res.json().catch(() => ({})));
    if (res.status === 403 && body.reason === "kyc_required") {
      return {
        ok: false,
        reason: "kyc_required",
        message: body.error ?? "This store's payments are still pending identity verification.",
      };
    }
    return { ok: false, reason: "other", message: body.error ?? `Couldn't start payment (${res.status}).` };
  }

  const body = createPaymentLinkResponseSchema.parse(await res.json());
  return { ok: true, token: body.link.token };
}
