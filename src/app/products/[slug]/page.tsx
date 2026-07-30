"use client"

import { use } from "react"
import { useDocuments } from "@/hooks/useCollection"
import { PRODUCTS_COLLECTION_ID } from "@/lib/config"
import { formatMoney, discountPercent } from "@/lib/utils"
import { parseJsonField } from "@/lib/json-field"
import type { Product } from "@/types/product"
import { AddToCartForm } from "@/components/catalog/AddToCartForm"
import { ImageCarousel } from "@/components/catalog/ImageCarousel"
import { Badge } from "@/components/ui/badge"

export default function ProductDetailPage({ params }: { params: Promise<{ slug: string }> }): React.JSX.Element {
  const { slug } = use(params)
  const { data, isLoading, isError } = useDocuments<Product>(PRODUCTS_COLLECTION_ID, { filter: { slug } })
  const product = data?.data[0]

  if (isLoading) {
    return (
      <div className="container grid grid-cols-1 gap-10 py-10 md:grid-cols-2">
        <div className="aspect-square animate-pulse rounded-lg bg-muted" />
        <div className="space-y-4">
          <div className="h-8 w-2/3 animate-pulse rounded bg-muted" />
          <div className="h-6 w-1/3 animate-pulse rounded bg-muted" />
        </div>
      </div>
    )
  }

  if (isError || !product) {
    return (
      <div className="container py-16 text-center">
        <p className="text-muted-foreground">This product isn&apos;t available anymore.</p>
      </div>
    )
  }

  const gallery = parseJsonField<string[]>(product.galleryJson, [])
  const images = [product.imageUrl, ...gallery].filter((url): url is string => Boolean(url))
  const percentOff = discountPercent(product.priceCents, product.compareAtPriceCents)

  return (
    <div className="container grid grid-cols-1 gap-10 py-10 md:grid-cols-2">
      <ImageCarousel images={images} alt={product.name} />

      <div className="space-y-6">
        <div className="space-y-2">
          <div className="flex items-center gap-2">
            {product.category && <Badge variant="secondary">{product.category}</Badge>}
            {percentOff !== null && <Badge>{percentOff}% off</Badge>}
          </div>
          <h1 className="font-display text-3xl font-semibold tracking-tight">{product.name}</h1>
          <div className="flex items-baseline gap-2">
            <p className="text-2xl font-semibold tabular-nums">{formatMoney(product.priceCents, product.currency)}</p>
            {percentOff !== null && (
              <p className="text-base tabular-nums text-muted-foreground line-through">
                {formatMoney(product.compareAtPriceCents as number, product.currency)}
              </p>
            )}
          </div>
        </div>

        {product.description && (
          <p className="whitespace-pre-line leading-relaxed text-muted-foreground">{product.description}</p>
        )}

        <AddToCartForm product={product} />

        <p className="text-sm text-muted-foreground">
          {product.stock > 0 ? `${product.stock} in stock` : "Currently out of stock"}
        </p>
      </div>
    </div>
  )
}
