"use client"

import { use } from "react"
import { useDocument, useUpdateDocument } from "@/hooks/useCollection"
import { PRODUCTS_COLLECTION_ID } from "@/lib/config"
import { parseJsonField, stringifyJsonField } from "@/lib/json-field"
import { SellerGuard } from "@/components/seller/SellerGuard"
import { ProductForm, type ProductFormValues } from "@/components/seller/ProductForm"
import type { Product } from "@/types/product"

export default function EditProductPage({ params }: { params: Promise<{ id: string }> }): React.JSX.Element {
  const { id } = use(params)
  const { data: product, isLoading } = useDocument<Product>(PRODUCTS_COLLECTION_ID, id)
  const updateProduct = useUpdateDocument<Product>(PRODUCTS_COLLECTION_ID)

  const handleSave = async (values: ProductFormValues): Promise<void> => {
    const { galleryUrls, ...rest } = values
    await updateProduct.mutateAsync({
      documentId: id,
      data: {
        ...rest,
        imageUrl: values.imageUrl || undefined,
        galleryJson: stringifyJsonField(galleryUrls.map((g) => g.url)),
      },
    })
  }

  return (
    <SellerGuard>
      <div className="container py-10">
        <h1 className="mb-6 font-display text-2xl font-semibold tracking-tight">Edit product</h1>
        {isLoading || !product ? (
          <div className="h-64 max-w-lg animate-pulse rounded-lg bg-muted" />
        ) : (
          <ProductForm
            initialValues={{
              name: product.name,
              description: product.description ?? "",
              priceCents: product.priceCents,
              compareAtPriceCents: product.compareAtPriceCents,
              currency: product.currency,
              imageUrl: product.imageUrl ?? "",
              galleryUrls: parseJsonField<string[]>(product.galleryJson, []).map((url) => ({ url })),
              category: product.category ?? "",
              stock: product.stock,
              isActive: product.isActive,
            }}
            onSave={handleSave}
          />
        )}
      </div>
    </SellerGuard>
  )
}
