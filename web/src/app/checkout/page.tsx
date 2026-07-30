"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { useCart, migrateGuestCartToServer } from "@/hooks/useCart"
import { ORDERS_COLLECTION_ID } from "@/lib/config"
import { stringifyJsonField } from "@/lib/json-field"
import { RegisterForm } from "@/components/auth/RegisterForm"
import { LoginForm } from "@/components/auth/LoginForm"
import { ShippingForm } from "@/components/checkout/ShippingForm"
import { OrderSummary } from "@/components/checkout/OrderSummary"
import type { ShippingAddress } from "@/types/order"

export default function CheckoutPage(): React.JSX.Element {
  const router = useRouter()
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()
  const { items, subtotalCents, clear, isLoading: cartLoading } = useCart()
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [authMode, setAuthMode] = useState<"register" | "login">("register")

  const isCustomer = session?.user?.customRole === "customer"

  // Right after registration succeeds, isCustomer flips true before the now-customer's server
  // cart (migrated from the guest cart moments earlier) has actually loaded - items is
  // momentarily [] during that window. Without this check, a shopper who just registered to
  // complete checkout would see "cart is empty" and never reach the shipping form at all, even
  // though their cart and the order they were about to place still exist.
  if (cartLoading) {
    return (
      <div className="container py-16 text-center">
        <div className="mx-auto h-6 w-6 animate-spin rounded-full border-2 border-muted border-t-foreground" />
      </div>
    )
  }

  if (items.length === 0) {
    return (
      <div className="container py-16 text-center">
        <p className="text-muted-foreground">Your cart is empty — add something before checking out.</p>
      </div>
    )
  }

  const handleAccountCreated = async (): Promise<void> => {
    const currentSession = await client.getSession().catch(() => null)
    if (currentSession?.user?.id) {
      await migrateGuestCartToServer(client, currentSession.user.id)
      await queryClient.invalidateQueries({ queryKey: ["cart", currentSession.user.id] })
    }
  }

  const placeOrder = async (address: ShippingAddress): Promise<void> => {
    setSubmitting(true)
    setError(null)
    try {
      const currency = "USDC"
      const network = "POLYGON"
      const amount = (subtotalCents / 100).toFixed(2)

      const order = await client.createDocument(ORDERS_COLLECTION_ID, {
        userId: session?.user?.id,
        itemsJson: stringifyJsonField(items.map((i) => ({ productId: i.productId, name: i.name, priceCents: i.priceCents, quantity: i.quantity }))),
        subtotalCents,
        currency: "USD",
        orderStatus: "awaiting_payment",
        shippingName: address.fullName,
        shippingAddressJson: stringifyJsonField(address),
        paymentStatus: "unpaid",
      })

      // This bypasses useCreateDocument (which would invalidate ["collection", ORDERS_COLLECTION_ID]
      // automatically) because the pay-link call below still needs to run even if it fails - so the
      // order must be created and visible in Orders regardless of the payment-link outcome. Without
      // this, the Orders list's cached query (up to 30s stale) could keep showing "no orders" right
      // after checkout if the shopper had viewed Orders earlier in the same session.
      await queryClient.invalidateQueries({ queryKey: ["collection", ORDERS_COLLECTION_ID] })

      const orderId = order._id as string
      const redirectUrl = `${window.location.origin}/orders/${orderId}`

      const res = await fetch("/api/checkout/pay-link", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ orderId, amount, currency, network, redirectUrl }),
      })

      if (!res.ok) {
        const body = (await res.json().catch(() => ({}))) as { error?: string; reason?: string }
        if (body.reason === "kyc_required") {
          await client.updateDocument(ORDERS_COLLECTION_ID, orderId, { orderStatus: "pending" })
          setError(body.error ?? "This store's payments are still pending identity verification.")
          return
        }
        setError(body.error ?? "Couldn't start payment. Please try again.")
        return
      }

      const body = (await res.json()) as { link: { token: string } }
      await client.updateDocument(ORDERS_COLLECTION_ID, orderId, { paymentLinkToken: body.link.token })
      await clear()
      router.push(`/checkout/${body.link.token}`)
    } catch {
      setError("Something went wrong placing your order. Please try again.")
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="container grid grid-cols-1 gap-10 py-10 lg:grid-cols-3">
      <div className="space-y-6 lg:col-span-2">
        <h1 className="font-display text-2xl font-semibold tracking-tight">Checkout</h1>

        {!isCustomer ? (
          <div className="space-y-3">
            {authMode === "register" ? (
              <>
                <p className="text-sm text-muted-foreground">
                  Create an account to place this order — your cart carries over, and you&apos;ll be able to track
                  it from Orders afterward.
                </p>
                <RegisterForm onSuccess={() => void handleAccountCreated()} />
                <p className="text-sm text-muted-foreground">
                  Already have an account?{" "}
                  <button
                    type="button"
                    onClick={() => setAuthMode("login")}
                    className="underline underline-offset-4"
                  >
                    Sign in
                  </button>
                </p>
              </>
            ) : (
              <>
                <p className="text-sm text-muted-foreground">
                  Sign in to continue — your cart carries over to your account.
                </p>
                <LoginForm onSuccess={() => void handleAccountCreated()} />
                <p className="text-sm text-muted-foreground">
                  New here?{" "}
                  <button
                    type="button"
                    onClick={() => setAuthMode("register")}
                    className="underline underline-offset-4"
                  >
                    Create an account
                  </button>
                </p>
              </>
            )}
          </div>
        ) : (
          <>
            {error && (
              <p role="alert" className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
                {error}
              </p>
            )}
            <ShippingForm onSubmit={placeOrder} submitting={submitting} />
          </>
        )}
      </div>
      <div>
        <OrderSummary />
      </div>
    </div>
  )
}
