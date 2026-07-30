import { formatMoney } from "@/lib/utils"
import type { OrderLineItem } from "@/types/order"

export function OrderItemsTable({ items, currency }: { items: OrderLineItem[]; currency: string }): React.JSX.Element {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-muted-foreground">
            <th className="py-2 font-normal">Item</th>
            <th className="py-2 text-right font-normal">Qty</th>
            <th className="py-2 text-right font-normal">Price</th>
            <th className="py-2 text-right font-normal">Total</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.productId} className="border-b border-border last:border-0">
              <td className="py-2">{item.name}</td>
              <td className="py-2 text-right tabular-nums">{item.quantity}</td>
              <td className="py-2 text-right tabular-nums">{formatMoney(item.priceCents, currency)}</td>
              <td className="py-2 text-right tabular-nums">{formatMoney(item.priceCents * item.quantity, currency)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
