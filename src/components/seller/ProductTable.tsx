"use client"

import Link from "next/link"
import { Pencil, Trash2 } from "lucide-react"
import { useDocuments, useDeleteDocument } from "@/hooks/useCollection"
import { PRODUCTS_COLLECTION_ID } from "@/lib/config"
import { formatMoney, discountPercent } from "@/lib/utils"
import type { Product } from "@/types/product"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

export function ProductTable(): React.JSX.Element {
  const { data, isLoading, isError } = useDocuments<Product>(PRODUCTS_COLLECTION_ID, { sort: "-createdAt", limit: 100 })
  const deleteProduct = useDeleteDocument(PRODUCTS_COLLECTION_ID)

  if (isLoading) return <div className="h-48 animate-pulse rounded-lg bg-muted" />
  if (isError) return <p className="text-sm text-destructive">Couldn&apos;t load products.</p>

  const products = data?.data ?? []

  if (products.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border py-16 text-center">
        <p className="mb-4 text-muted-foreground">No products listed yet.</p>
        <Button asChild>
          <Link href="/seller/products/new">Add your first product</Link>
        </Button>
      </div>
    )
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border bg-muted/40 text-left">
            <th className="px-4 py-3 font-medium">Name</th>
            <th className="px-4 py-3 text-right font-medium">Price</th>
            <th className="px-4 py-3 text-right font-medium">Stock</th>
            <th className="px-4 py-3 font-medium">Status</th>
            <th className="px-4 py-3" />
          </tr>
        </thead>
        <tbody>
          {products.map((product) => {
            const percentOff = discountPercent(product.priceCents, product.compareAtPriceCents)
            return (
            <tr key={product._id} className="border-b border-border last:border-0">
              <td className="max-w-xs truncate px-4 py-3">{product.name}</td>
              <td className="px-4 py-3 text-right tabular-nums">
                <div className="flex items-baseline justify-end gap-1.5">
                  {percentOff !== null && (
                    <span className="text-xs text-muted-foreground line-through">
                      {formatMoney(product.compareAtPriceCents as number, product.currency)}
                    </span>
                  )}
                  <span>{formatMoney(product.priceCents, product.currency)}</span>
                  {percentOff !== null && <Badge variant="secondary">-{percentOff}%</Badge>}
                </div>
              </td>
              <td className="px-4 py-3 text-right tabular-nums">{product.stock}</td>
              <td className="px-4 py-3">
                <Badge variant={product.isActive ? "success" : "secondary"}>
                  {product.isActive ? "Active" : "Hidden"}
                </Badge>
              </td>
              <td className="px-4 py-3">
                <div className="flex justify-end gap-1">
                  <Button asChild variant="ghost" size="icon">
                    <Link href={`/seller/products/${product._id}/edit`} aria-label={`Edit ${product.name}`}>
                      <Pencil className="h-4 w-4" />
                    </Link>
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label={`Delete ${product.name}`}
                    onClick={() => {
                      if (window.confirm(`Delete "${product.name}"? This can't be undone.`)) {
                        deleteProduct.mutate(product._id)
                      }
                    }}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </td>
            </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
