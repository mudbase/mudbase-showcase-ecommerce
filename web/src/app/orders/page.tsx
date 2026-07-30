import { OrderList } from "@/components/orders/OrderList"

export default function OrdersPage(): React.JSX.Element {
  return (
    <div className="container py-10">
      <h1 className="mb-6 font-display text-2xl font-semibold tracking-tight">Your orders</h1>
      <OrderList />
    </div>
  )
}
