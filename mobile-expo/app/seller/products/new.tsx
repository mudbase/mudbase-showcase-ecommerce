import { ScrollView } from "react-native";
import { router } from "expo-router";
import { useAuth } from "@/hooks/useAuth";
import { useCreateDocument } from "@/hooks/useCollection";
import { PRODUCTS_COLLECTION_ID } from "@/config/env";
import { productSchema } from "@/api/schemas";
import { slugify } from "@/lib/format";
import { ProductForm, toProductPayload, type ProductFormValues } from "@/components/seller/ProductForm";

export default function NewProductScreen(): React.JSX.Element {
  const { user } = useAuth();
  const createProduct = useCreateDocument(productSchema, PRODUCTS_COLLECTION_ID);

  const handleSave = async (values: ProductFormValues): Promise<void> => {
    const payload = toProductPayload(values);
    await createProduct.mutateAsync({
      ...payload,
      slug: `${slugify(values.name)}-${Math.random().toString(36).slice(2, 8)}`,
      sellerId: user?.id,
    });
    router.back();
  };

  return (
    <ScrollView className="flex-1 bg-background" contentContainerClassName="p-4">
      <ProductForm onSave={handleSave} />
    </ScrollView>
  );
}
