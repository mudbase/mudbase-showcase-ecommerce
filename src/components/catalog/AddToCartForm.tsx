"use client"

import { useState } from "react"
import { Minus, Plus, ShoppingBag } from "lucide-react"
import { useCart } from "@/hooks/useCart"
import { Button } from "@/components/ui/button"
import type { Product } from "@/types/product"

export function AddToCartForm({ product }: { product: Product }): React.JSX.Element {
  const { addItem } = useCart()
  const [quantity, setQuantity] = useState(1)
  const [status, setStatus] = useState<"idle" | "adding" | "added" | "error">("idle")
  const outOfStock = product.stock <= 0

  const handleAdd = async (): Promise<void> => {
    setStatus("adding")
    try {
      await addItem(
        {
          productId: product._id,
          name: product.name,
          priceCents: product.priceCents,
          currency: product.currency,
          imageUrl: product.imageUrl,
        },
        quantity,
      )
      setStatus("added")
      setTimeout(() => setStatus("idle"), 1500)
    } catch {
      // Without this, a failed add (network blip, a permission/validation error) left the
      // button silently stuck on "Adding..." forever with no feedback - indistinguishable from
      // clicking "Add to cart" simply not doing anything.
      setStatus("error")
      setTimeout(() => setStatus("idle"), 2500)
    }
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-3">
        <div className="flex items-center rounded-md border border-input">
          <button
            type="button"
            aria-label="Decrease quantity"
            onClick={() => setQuantity((q) => Math.max(1, q - 1))}
            className="flex h-10 w-10 items-center justify-center hover:bg-accent/10"
          >
            <Minus className="h-4 w-4" />
          </button>
          <span className="w-8 text-center tabular-nums">{quantity}</span>
          <button
            type="button"
            aria-label="Increase quantity"
            onClick={() => setQuantity((q) => Math.min(product.stock || 1, q + 1))}
            className="flex h-10 w-10 items-center justify-center hover:bg-accent/10"
          >
            <Plus className="h-4 w-4" />
          </button>
        </div>
        <Button onClick={() => void handleAdd()} disabled={outOfStock || status === "adding"} className="flex-1">
          <ShoppingBag className="mr-2 h-4 w-4" />
          {outOfStock ? "Out of stock" : status === "added" ? "Added to cart" : status === "error" ? "Couldn't add — try again" : "Add to cart"}
        </Button>
      </div>
      {status === "error" && (
        <p role="alert" className="text-xs text-destructive">
          Something went wrong adding this to your cart. Please try again.
        </p>
      )}
    </div>
  )
}
