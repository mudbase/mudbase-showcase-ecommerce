"use client"

import Link from "next/link"
import { useCart } from "@/hooks/useCart"
import { formatMoney } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"

export function CartSummary(): React.JSX.Element {
  const { items, subtotalCents } = useCart()
  const currency = items[0]?.currency ?? "USD"

  return (
    <div className="space-y-4 rounded-lg border border-border p-6">
      <h2 className="font-medium">Order summary</h2>
      <div className="flex justify-between text-sm">
        <span className="text-muted-foreground">Subtotal</span>
        <span className="tabular-nums">{formatMoney(subtotalCents, currency)}</span>
      </div>
      <Separator />
      <div className="flex justify-between font-medium">
        <span>Total</span>
        <span className="tabular-nums">{formatMoney(subtotalCents, currency)}</span>
      </div>
      <Button asChild className="w-full" disabled={items.length === 0}>
        <Link href="/checkout" aria-disabled={items.length === 0}>
          Checkout
        </Link>
      </Button>
    </div>
  )
}
