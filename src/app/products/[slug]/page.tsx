"use client"

import { use } from "react"
import Image from "next/image"
import { useDocuments } from "@/hooks/useCollection"
import { PRODUCTS_COLLECTION_ID } from "@/lib/config"
import { formatMoney } from "@/lib/utils"
import { parseJsonField } from "@/lib/json-field"
import type { Product } from "@/types/product"
import { AddToCartForm } from "@/components/catalog/AddToCartForm"
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

  return (
    <div className="container grid grid-cols-1 gap-10 py-10 md:grid-cols-2">
      <div className="space-y-3">
        <div className="relative aspect-square overflow-hidden rounded-lg bg-muted">
          {product.imageUrl ? (
            <Image src={product.imageUrl} alt={product.name} fill sizes="(min-width: 768px) 50vw, 100vw" className="object-cover" />
          ) : (
            <div className="flex h-full items-center justify-center text-sm text-muted-foreground">No image</div>
          )}
        </div>
        {gallery.length > 0 && (
          <div className="grid grid-cols-4 gap-2">
            {gallery.map((url) => (
              <div key={url} className="relative aspect-square overflow-hidden rounded-md bg-muted">
                <Image src={url} alt="" fill sizes="120px" className="object-cover" />
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="space-y-6">
        <div className="space-y-2">
          {product.category && <Badge variant="secondary">{product.category}</Badge>}
          <h1 className="font-display text-3xl font-semibold tracking-tight">{product.name}</h1>
          <p className="text-2xl font-semibold tabular-nums">{formatMoney(product.priceCents, product.currency)}</p>
        </div>

        {product.description && <p className="leading-relaxed text-muted-foreground">{product.description}</p>}

        <AddToCartForm product={product} />

        <p className="text-sm text-muted-foreground">
          {product.stock > 0 ? `${product.stock} in stock` : "Currently out of stock"}
        </p>
      </div>
    </div>
  )
}
