"use client"

import { useState, useMemo } from "react"
import { useDocuments } from "@/hooks/useCollection"
import { PRODUCTS_COLLECTION_ID } from "@/lib/config"
import type { Product } from "@/types/product"
import { ProductCard } from "./ProductCard"
import { CategoryFilter } from "./CategoryFilter"

export function ProductGrid(): React.JSX.Element {
  const [category, setCategory] = useState<string | null>(null)

  const filter = useMemo(
    () => (category ? { isActive: true, category } : { isActive: true }),
    [category],
  )

  const { data, isLoading, isError } = useDocuments<Product>(PRODUCTS_COLLECTION_ID, {
    filter,
    sort: "-createdAt",
    limit: 60,
  })

  const categories = useMemo(() => {
    const set = new Set<string>()
    for (const p of data?.data ?? []) {
      if (p.category) set.add(p.category)
    }
    return Array.from(set).sort()
  }, [data])

  if (isLoading) {
    return (
      <div className="grid grid-cols-2 gap-6 sm:grid-cols-3 lg:grid-cols-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="aspect-square animate-pulse rounded-lg bg-muted" />
        ))}
      </div>
    )
  }

  if (isError) {
    return <p className="text-sm text-destructive">Couldn&apos;t load the catalog right now. Try refreshing.</p>
  }

  const products = data?.data ?? []

  return (
    <div className="space-y-6">
      {categories.length > 0 && <CategoryFilter categories={categories} value={category} onChange={setCategory} />}
      {products.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border py-16 text-center">
          <p className="text-muted-foreground">
            {category ? `No products in "${category}" yet.` : "No products listed yet — check back soon."}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-6 sm:grid-cols-3 lg:grid-cols-4">
          {products.map((product) => (
            <ProductCard key={product._id} product={product} />
          ))}
        </div>
      )}
    </div>
  )
}
