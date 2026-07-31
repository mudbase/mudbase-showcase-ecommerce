import { useEffect } from "react";
import { ScrollView } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { z } from "zod";
import { useDocument, useUpdateDocument } from "@/hooks/useCollection";
import { PRODUCTS_COLLECTION_ID } from "@/config/env";
import { productSchema } from "@/api/schemas";
import { parseJsonField } from "@/lib/jsonField";
import { ProductForm, toProductPayload, type ProductFormValues } from "@/components/seller/ProductForm";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

const paramsSchema = z.object({ id: z.string().min(1) });

export default function EditProductScreen(): React.JSX.Element {
  const params = useLocalSearchParams();
  const parsed = paramsSchema.safeParse(params);
  const id = parsed.success ? parsed.data.id : undefined;

  const { data: product, isLoading } = useDocument(productSchema, PRODUCTS_COLLECTION_ID, id);
  const updateProduct = useUpdateDocument(productSchema, PRODUCTS_COLLECTION_ID);

  useEffect(() => {
    if (!parsed.success) router.back();
  }, [parsed.success]);

  if (!parsed.success || isLoading || !product) {
    return (
      <ScrollView className="flex-1 bg-background" contentContainerClassName="p-4">
        <LoadingBlock className="h-64" />
      </ScrollView>
    );
  }

  const handleSave = async (values: ProductFormValues): Promise<void> => {
    await updateProduct.mutateAsync({ documentId: product._id, data: toProductPayload(values) });
    router.back();
  };

  return (
    <ScrollView className="flex-1 bg-background" contentContainerClassName="p-4">
      <ProductForm
        submitLabel="Save changes"
        initialValues={{
          name: product.name,
          description: product.description ?? "",
          priceCents: String(product.priceCents),
          compareAtPriceCents: product.compareAtPriceCents !== undefined ? String(product.compareAtPriceCents) : undefined,
          currency: product.currency,
          imageUrl: product.imageUrl ?? "",
          galleryUrls: parseJsonField<string[]>(product.galleryJson, []).map((url) => ({ url })),
          category: product.category ?? "",
          stock: String(product.stock),
          isActive: product.isActive,
        }}
        onSave={handleSave}
      />
    </ScrollView>
  );
}
