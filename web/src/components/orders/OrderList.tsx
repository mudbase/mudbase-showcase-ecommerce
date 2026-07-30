"use client"

import Link from "next/link"
import { useMudbase } from "@/lib/mudbase-provider"
import { useDocuments } from "@/hooks/useCollection"
import { ORDERS_COLLECTION_ID } from "@/lib/config"
import { formatMoney, formatDate } from "@/lib/utils"
import type { Order } from "@/types/order"
import { OrderStatusBadge } from "./OrderStatusBadge"

export function OrderList(): React.JSX.Element {
  const { session } = useMudbase()
  const userId = session?.user?.id

  const { data, isLoading, isError } = useDocuments<Order>(
    ORDERS_COLLECTION_ID,
    { filter: { userId }, sort: "-createdAt" },
    { enabled: !!userId },
  )

  if (isLoading) {
    return (
      <div className="space-y-2">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="h-16 animate-pulse rounded-md bg-muted" />
        ))}
      </div>
    )
  }

  if (isError) {
    return <p className="text-sm text-destructive">Couldn&apos;t load your orders right now.</p>
  }

  const orders = data?.data ?? []

  if (orders.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border py-16 text-center">
        <p className="text-muted-foreground">No orders yet.</p>
      </div>
    )
  }

  return (
    <ul className="divide-y divide-border rounded-lg border border-border">
      {orders.map((order) => (
        <li key={order._id}>
          <Link href={`/orders/${order._id}`} className="flex items-center justify-between gap-4 p-4 hover:bg-accent/5">
            <div>
              <p className="font-medium">Order #{order._id.slice(-6).toUpperCase()}</p>
              <p className="text-sm text-muted-foreground">{formatDate(order.createdAt)}</p>
            </div>
            <div className="flex items-center gap-4">
              <span className="tabular-nums">{formatMoney(order.subtotalCents, order.currency)}</span>
              <OrderStatusBadge status={order.orderStatus} />
            </div>
          </Link>
        </li>
      ))}
    </ul>
  )
}
