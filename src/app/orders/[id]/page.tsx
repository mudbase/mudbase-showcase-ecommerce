"use client"

import { use } from "react"
import Link from "next/link"
import { useDocument } from "@/hooks/useCollection"
import { ORDERS_COLLECTION_ID } from "@/lib/config"
import { parseJsonField } from "@/lib/json-field"
import { formatMoney, formatDate } from "@/lib/utils"
import type { Order, OrderLineItem, ShippingAddress } from "@/types/order"
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge"
import { OrderTimeline } from "@/components/orders/OrderTimeline"
import { OrderItemsTable } from "@/components/orders/OrderItemsTable"
import { Separator } from "@/components/ui/separator"
import { Button } from "@/components/ui/button"

export default function OrderDetailPage({ params }: { params: Promise<{ id: string }> }): React.JSX.Element {
  const { id } = use(params)
  const { data: order, isLoading, isError } = useDocument<Order>(ORDERS_COLLECTION_ID, id)

  if (isLoading) {
    return (
      <div className="container py-10">
        <div className="h-64 animate-pulse rounded-lg bg-muted" />
      </div>
    )
  }

  if (isError || !order) {
    return (
      <div className="container py-16 text-center">
        <p className="text-muted-foreground">This order couldn&apos;t be found.</p>
      </div>
    )
  }

  const items = parseJsonField<OrderLineItem[]>(order.itemsJson, [])
  const address = parseJsonField<ShippingAddress | null>(order.shippingAddressJson, null)

  return (
    <div className="container max-w-2xl space-y-8 py-10">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-semibold tracking-tight">
            Order #{order._id.slice(-6).toUpperCase()}
          </h1>
          <p className="text-sm text-muted-foreground">{formatDate(order.createdAt)}</p>
        </div>
        <OrderStatusBadge status={order.orderStatus} />
      </div>

      <OrderTimeline status={order.orderStatus} />

      <Separator />

      <div>
        <h2 className="mb-3 font-medium">Items</h2>
        <OrderItemsTable items={items} currency={order.currency} />
        <div className="mt-3 flex justify-between font-medium">
          <span>Total</span>
          <span className="tabular-nums">{formatMoney(order.subtotalCents, order.currency)}</span>
        </div>
      </div>

      {address && (
        <div>
          <h2 className="mb-2 font-medium">Shipping to</h2>
          <p className="text-sm text-muted-foreground">
            {address.fullName}
            <br />
            {address.line1}
            {address.line2 ? `, ${address.line2}` : ""}
            <br />
            {address.city}, {address.region} {address.postalCode}
            <br />
            {address.country}
          </p>
        </div>
      )}

      {order.paymentLinkToken && order.paymentStatus !== "paid" && (
        <Button asChild>
          <Link href={`/checkout/${order.paymentLinkToken}`}>Complete payment</Link>
        </Button>
      )}
    </div>
  )
}
