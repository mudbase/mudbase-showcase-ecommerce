import type { Document } from "@/lib/mudbase"

export interface Product extends Document {
  name: string
  slug: string
  description?: string
  priceCents: number
  currency: string
  imageUrl?: string
  galleryJson?: string
  category?: string
  stock: number
  isActive: boolean
  sellerId?: string
}

export interface ProductFormValues {
  name: string
  slug: string
  description: string
  priceCents: number
  currency: string
  imageUrl: string
  category: string
  stock: number
  isActive: boolean
}
