"use client"

import Link from "next/link"
import { useDocuments, useUpdateDocument } from "@/hooks/useCollection"
import { useOrdersLive } from "@/hooks/useOrdersLive"
import { ORDERS_COLLECTION_ID } from "@/lib/config"
import { formatMoney, formatDate } from "@/lib/utils"
import type { Order, OrderStatus } from "@/types/order"
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge"
import { Button } from "@/components/ui/button"

const NEXT_STATUS: Partial<Record<OrderStatus, OrderStatus>> = {
  paid: "shipped",
  shipped: "delivered",
}

export function SellerOrderQueue(): React.JSX.Element {
  const { data, isLoading, isError } = useDocuments<Order>(ORDERS_COLLECTION_ID, { sort: "-createdAt", limit: 100 })
  const updateOrder = useUpdateDocument<Order>(ORDERS_COLLECTION_ID)
  useOrdersLive(ORDERS_COLLECTION_ID, true)

  if (isLoading) return <div className="h-48 animate-pulse rounded-lg bg-muted" />
  if (isError) return <p className="text-sm text-destructive">Couldn&apos;t load orders.</p>

  const orders = data?.data ?? []

  if (orders.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border py-16 text-center">
        <p className="text-muted-foreground">No orders yet — they&apos;ll appear here the instant one comes in.</p>
      </div>
    )
  }

  return (
    <ul className="divide-y divide-border rounded-lg border border-border">
      {orders.map((order) => {
        const nextStatus = NEXT_STATUS[order.orderStatus]
        return (
          <li key={order._id} className="flex items-center justify-between gap-4 p-4">
            <div className="min-w-0">
              <Link href={`/orders/${order._id}`} className="font-medium hover:underline">
                Order #{order._id.slice(-6).toUpperCase()}
              </Link>
              <p className="text-sm text-muted-foreground">
                {order.shippingName ?? "Guest"} · {formatDate(order.createdAt)}
              </p>
            </div>
            <span className="tabular-nums">{formatMoney(order.subtotalCents, order.currency)}</span>
            <OrderStatusBadge status={order.orderStatus} />
            {nextStatus && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => updateOrder.mutate({ documentId: order._id, data: { orderStatus: nextStatus } })}
                disabled={updateOrder.isPending}
              >
                Mark {nextStatus}
              </Button>
            )}
          </li>
        )
      })}
    </ul>
  )
}
