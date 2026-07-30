"use client"

import { useEffect, useState } from "react"
import Image from "next/image"
import Link from "next/link"
import { formatMoney, discountPercent } from "@/lib/utils"
import { parseJsonField } from "@/lib/json-field"
import type { Product } from "@/types/product"
import { Card, CardContent, CardFooter } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

const HOVER_CYCLE_MS = 900

export function ProductCard({ product }: { product: Product }): React.JSX.Element {
  const outOfStock = product.stock <= 0
  const gallery = parseJsonField<string[]>(product.galleryJson, [])
  const images = [product.imageUrl, ...gallery].filter((url): url is string => Boolean(url))
  const percentOff = discountPercent(product.priceCents, product.compareAtPriceCents)

  const [isHovering, setIsHovering] = useState(false)
  const [frame, setFrame] = useState(0)

  useEffect(() => {
    if (!isHovering || images.length <= 1) return
    const id = setInterval(() => {
      setFrame((current) => (current + 1) % images.length)
    }, HOVER_CYCLE_MS)
    return () => clearInterval(id)
  }, [isHovering, images.length])

  const activeImage = images[isHovering ? frame : 0]

  return (
    <Link
      href={`/products/${product.slug}`}
      className="group block"
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => {
        setIsHovering(false)
        setFrame(0)
      }}
    >
      <Card className="overflow-hidden transition-shadow group-hover:shadow-md">
        <div className="relative aspect-square bg-muted">
          {activeImage ? (
            <Image
              src={activeImage}
              alt={product.name}
              fill
              sizes="(min-width: 1024px) 25vw, (min-width: 640px) 33vw, 50vw"
              className="object-cover transition-transform group-hover:scale-105"
            />
          ) : (
            <div className="flex h-full items-center justify-center text-sm text-muted-foreground">No image</div>
          )}
          <div className="absolute left-2 top-2 flex gap-1">
            {outOfStock && <Badge variant="secondary">Out of stock</Badge>}
            {percentOff !== null && <Badge>{percentOff}% off</Badge>}
          </div>
        </div>
        <CardContent className="p-4">
          <p className="text-xs uppercase tracking-wide text-muted-foreground">{product.category || "General"}</p>
          <h3 className="mt-1 line-clamp-1 font-medium">{product.name}</h3>
        </CardContent>
        <CardFooter className="flex items-baseline gap-2 px-4 pb-4 pt-0">
          <span className="font-semibold tabular-nums">{formatMoney(product.priceCents, product.currency)}</span>
          {percentOff !== null && (
            <span className="text-sm tabular-nums text-muted-foreground line-through">
              {formatMoney(product.compareAtPriceCents as number, product.currency)}
            </span>
          )}
        </CardFooter>
      </Card>
    </Link>
  )
}
