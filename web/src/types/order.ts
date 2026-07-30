import type { Document } from "@/lib/mudbase"

export interface OrderLineItem {
  productId: string
  name: string
  priceCents: number
  quantity: number
}

export interface ShippingAddress {
  fullName: string
  line1: string
  line2?: string
  city: string
  region: string
  postalCode: string
  country: string
}

export type OrderStatus = "pending" | "awaiting_payment" | "paid" | "shipped" | "delivered" | "cancelled"
export type OrderPaymentStatus = "unpaid" | "paid" | "expired" | "cancelled"

export interface Order extends Document {
  userId: string
  itemsJson: string
  subtotalCents: number
  currency: string
  // Named "orderStatus", not "status" - Mudbase's server-side role-assignment guard treats a
  // literal "status" field on ANY collection as a protected role field, rejecting writes from
  // non-owner/admin callers (i.e. every project end-user, sellers included). Real platform
  // constraint, not a typo - see README "Known limitations".
  orderStatus: OrderStatus
  shippingName?: string
  shippingAddressJson?: string
  paymentLinkToken?: string
  paymentStatus: OrderPaymentStatus
}
