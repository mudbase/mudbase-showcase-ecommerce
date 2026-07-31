import { z } from "zod";

/**
 * Runtime validation for every Mudbase response shape this app touches.
 *
 * Several of the generated `mudbase-sdk` response models under-describe the
 * real JSON the platform returns (see client.ts's top-of-file comment for the
 * specific, documented gaps — e.g. `registerWithRole` is typed `void`, and the
 * project-scoped user objects the SDK types omit `customRole`/`isAnonymous`
 * even though the live API includes them, mirroring what web/src/lib/mudbase.ts's
 * hand-written `UserObject` interface already relies on in production). Rather
 * than casting past the generated types with `as`, every SDK response is
 * widened to `unknown` (always assignable, no cast needed) and parsed through
 * one of these schemas — the project's own "no `any`, narrow `unknown` with
 * zod at boundaries" rule applied to a real third-party SDK, not just our own
 * API layer.
 */

// ─── Auth / User ──────────────────────────────────────────────────────────

export const mudbaseUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  firstName: z.string(),
  lastName: z.string(),
  // Multi-Role's app-level role ("customer" | "seller" | any future role) —
  // present on every project-based session response in production, even
  // though the generated LoginLocalUser200ResponseUser model omits it.
  customRole: z.string().nullable().optional(),
  emailVerified: z.boolean().optional(),
  isAnonymous: z.boolean().optional(),
});
export type MudbaseUser = z.infer<typeof mudbaseUserSchema>;

export const authResultSchema = z.object({
  message: z.string().optional(),
  token: z.string().optional(),
  refreshToken: z.string().optional(),
  expiresIn: z.number().optional(),
  requireVerification: z.boolean().optional(),
  user: mudbaseUserSchema.optional(),
});
export type AuthResult = z.infer<typeof authResultSchema>;

// ─── Documents (Collections) ──────────────────────────────────────────────

export const documentBaseSchema = z.object({
  _id: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const productSchema = documentBaseSchema.extend({
  name: z.string(),
  slug: z.string(),
  description: z.string().optional(),
  priceCents: z.number(),
  compareAtPriceCents: z.number().optional(),
  currency: z.string(),
  imageUrl: z.string().optional(),
  // JSON-array-as-string — Mudbase collection fields have no native array
  // type, so multi-image galleries are JSON-encoded and parsed at the edges
  // via lib/jsonField.ts (same platform constraint documented in web/README.md).
  galleryJson: z.string().optional(),
  category: z.string().optional(),
  stock: z.number(),
  isActive: z.boolean(),
  sellerId: z.string().optional(),
});
export type Product = z.infer<typeof productSchema>;

export const orderLineItemSchema = z.object({
  productId: z.string(),
  name: z.string(),
  priceCents: z.number(),
  quantity: z.number(),
});
export type OrderLineItem = z.infer<typeof orderLineItemSchema>;

export const shippingAddressSchema = z.object({
  fullName: z.string().min(1, "Full name is required"),
  line1: z.string().min(1, "Address is required"),
  line2: z.string().optional(),
  city: z.string().min(1, "City is required"),
  region: z.string().min(1, "State/region is required"),
  postalCode: z.string().min(1, "Postal code is required"),
  country: z.string().min(1, "Country is required"),
});
export type ShippingAddress = z.infer<typeof shippingAddressSchema>;

export const orderStatusSchema = z.enum([
  "pending",
  "awaiting_payment",
  "paid",
  "shipped",
  "delivered",
  "cancelled",
]);
export type OrderStatus = z.infer<typeof orderStatusSchema>;

export const orderPaymentStatusSchema = z.enum(["unpaid", "paid", "expired", "cancelled"]);
export type OrderPaymentStatus = z.infer<typeof orderPaymentStatusSchema>;

export const orderSchema = documentBaseSchema.extend({
  userId: z.string(),
  itemsJson: z.string(),
  subtotalCents: z.number(),
  currency: z.string(),
  // Named "orderStatus", not "status" - Mudbase's server-side role-assignment
  // guard globally blocks writes containing a literal "status" key for every
  // project end-user regardless of role/collection permissions (see
  // web/README.md "Known limitations"). Real platform constraint, kept
  // identical here so this app writes to the same field the seed data uses.
  orderStatus: orderStatusSchema,
  shippingName: z.string().optional(),
  shippingAddressJson: z.string().optional(),
  paymentLinkToken: z.string().optional(),
  paymentStatus: orderPaymentStatusSchema,
});
export type Order = z.infer<typeof orderSchema>;

export const cartItemSchema = z.object({
  productId: z.string(),
  name: z.string(),
  priceCents: z.number(),
  currency: z.string(),
  imageUrl: z.string().optional(),
  quantity: z.number(),
});
export type CartItem = z.infer<typeof cartItemSchema>;

export const cartSchema = documentBaseSchema.extend({
  userId: z.string(),
  itemsJson: z.string(),
});
export type Cart = z.infer<typeof cartSchema>;

// ─── Payment Links (public, unauthenticated read) ─────────────────────────

export const paymentLinkStatusSchema = z.enum(["pending", "paid", "expired", "cancelled"]);
export type PaymentLinkStatus = z.infer<typeof paymentLinkStatusSchema>;

export const publicPaymentLinkSchema = z.object({
  token: z.string(),
  amount: z.string().nullable(),
  currency: z.string(),
  network: z.string(),
  address: z.string(),
  description: z.string().nullable(),
  redirectUrl: z.string().nullable(),
  status: paymentLinkStatusSchema,
  expiresAt: z.string().nullable(),
});
export type PublicPaymentLink = z.infer<typeof publicPaymentLinkSchema>;

export const createPaymentLinkResponseSchema = z.object({
  link: z.object({ token: z.string() }),
});

export const paymentLinkErrorSchema = z.object({
  error: z.string().optional(),
  reason: z.enum(["kyc_required", "merchant_auth_failed", "unknown"]).optional(),
});
