"use client"

import { useMudbase } from "@/lib/mudbase-provider"
import { PRODUCTS_COLLECTION_ID } from "@/lib/config"
import { slugify } from "@/lib/utils"
import { SellerGuard } from "@/components/seller/SellerGuard"
import { ProductForm, type ProductFormValues } from "@/components/seller/ProductForm"

export default function NewProductPage(): React.JSX.Element {
  const { client, session } = useMudbase()

  const handleSave = async (values: ProductFormValues): Promise<void> => {
    await client.createDocument(PRODUCTS_COLLECTION_ID, {
      ...values,
      slug: `${slugify(values.name)}-${Math.random().toString(36).slice(2, 8)}`,
      imageUrl: values.imageUrl || undefined,
      sellerId: session?.user?.id,
    })
  }

  return (
    <SellerGuard>
      <div className="container py-10">
        <h1 className="mb-6 font-display text-2xl font-semibold tracking-tight">Add product</h1>
        <ProductForm onSave={handleSave} />
      </div>
    </SellerGuard>
  )
}
