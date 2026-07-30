"use client"

import Image from "next/image"
import { Minus, Plus, X } from "lucide-react"
import { useCart } from "@/hooks/useCart"
import { formatMoney } from "@/lib/utils"

export function CartLineItems(): React.JSX.Element {
  const { items, updateQuantity, removeItem } = useCart()

  if (items.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border py-16 text-center">
        <p className="text-muted-foreground">Your cart is empty.</p>
      </div>
    )
  }

  return (
    <ul className="divide-y divide-border">
      {items.map((item) => (
        <li key={item.productId} className="flex items-center gap-4 py-4">
          <div className="relative h-16 w-16 shrink-0 overflow-hidden rounded-md bg-muted">
            {item.imageUrl && <Image src={item.imageUrl} alt={item.name} fill sizes="64px" className="object-cover" />}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate font-medium">{item.name}</p>
            <p className="text-sm text-muted-foreground tabular-nums">
              {formatMoney(item.priceCents, item.currency)}
            </p>
          </div>
          <div className="flex items-center rounded-md border border-input">
            <button
              type="button"
              aria-label={`Decrease quantity of ${item.name}`}
              onClick={() => void updateQuantity(item.productId, item.quantity - 1)}
              className="flex h-8 w-8 items-center justify-center hover:bg-accent/10"
            >
              <Minus className="h-3 w-3" />
            </button>
            <span className="w-6 text-center text-sm tabular-nums">{item.quantity}</span>
            <button
              type="button"
              aria-label={`Increase quantity of ${item.name}`}
              onClick={() => void updateQuantity(item.productId, item.quantity + 1)}
              className="flex h-8 w-8 items-center justify-center hover:bg-accent/10"
            >
              <Plus className="h-3 w-3" />
            </button>
          </div>
          <p className="w-20 text-right font-medium tabular-nums">
            {formatMoney(item.priceCents * item.quantity, item.currency)}
          </p>
          <button
            type="button"
            aria-label={`Remove ${item.name} from cart`}
            onClick={() => void removeItem(item.productId)}
            className="text-muted-foreground hover:text-destructive"
          >
            <X className="h-4 w-4" />
          </button>
        </li>
      ))}
    </ul>
  )
}
