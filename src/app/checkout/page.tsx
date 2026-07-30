"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { useCart, migrateGuestCartToServer } from "@/hooks/useCart"
import { ORDERS_COLLECTION_ID } from "@/lib/config"
import { stringifyJsonField } from "@/lib/json-field"
import { RegisterForm } from "@/components/auth/RegisterForm"
import { ShippingForm } from "@/components/checkout/ShippingForm"
import { OrderSummary } from "@/components/checkout/OrderSummary"
import type { ShippingAddress } from "@/types/order"

export default function CheckoutPage(): React.JSX.Element {
  const router = useRouter()
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()
  const { items, subtotalCents, clear } = useCart()
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const isCustomer = session?.user?.customRole === "customer"

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
            <p className="text-sm text-muted-foreground">
              Create an account to place this order — your cart carries over, and you&apos;ll be able to track it
              from Orders afterward.
            </p>
            <RegisterForm onSuccess={() => void handleAccountCreated()} />
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
