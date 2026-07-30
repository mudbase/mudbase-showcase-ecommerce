import type { Document } from "@/lib/mudbase"

export interface CartItem {
  productId: string
  name: string
  priceCents: number
  currency: string
  imageUrl?: string
  quantity: number
}

export interface Cart extends Document {
  userId: string
  itemsJson: string
}
