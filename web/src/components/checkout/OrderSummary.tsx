"use client"

import { useCart } from "@/hooks/useCart"
import { formatMoney } from "@/lib/utils"
import { Separator } from "@/components/ui/separator"

export function OrderSummary(): React.JSX.Element {
  const { items, subtotalCents } = useCart()
  const currency = items[0]?.currency ?? "USD"

  return (
    <div className="space-y-4 rounded-lg border border-border p-6">
      <h2 className="font-medium">Order summary</h2>
      <ul className="space-y-2 text-sm">
        {items.map((item) => (
          <li key={item.productId} className="flex justify-between">
            <span className="text-muted-foreground">
              {item.name} × {item.quantity}
            </span>
            <span className="tabular-nums">{formatMoney(item.priceCents * item.quantity, item.currency)}</span>
          </li>
        ))}
      </ul>
      <Separator />
      <div className="flex justify-between font-medium">
        <span>Total</span>
        <span className="tabular-nums">{formatMoney(subtotalCents, currency)}</span>
      </div>
    </div>
  )
}
