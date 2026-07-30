import { Badge } from "@/components/ui/badge"
import type { OrderStatus } from "@/types/order"

const LABELS: Record<OrderStatus, string> = {
  pending: "Pending",
  awaiting_payment: "Awaiting payment",
  paid: "Paid",
  shipped: "Shipped",
  delivered: "Delivered",
  cancelled: "Cancelled",
}

export function OrderStatusBadge({ status }: { status: OrderStatus }): React.JSX.Element {
  if (status === "delivered" || status === "paid") return <Badge variant="success">{LABELS[status]}</Badge>
  if (status === "cancelled") return <Badge variant="destructive">{LABELS[status]}</Badge>
  if (status === "awaiting_payment" || status === "pending") return <Badge variant="warning">{LABELS[status]}</Badge>
  return <Badge variant="secondary">{LABELS[status]}</Badge>
}
