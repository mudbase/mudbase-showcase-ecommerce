import { useCallback, useMemo, useState } from "react";
import { FlatList, Text, View, type ListRenderItemInfo } from "react-native";
import { useDocuments } from "@/hooks/useCollection";
import { PRODUCTS_COLLECTION_ID } from "@/config/env";
import { productSchema, type Product } from "@/api/schemas";
import { ProductCard } from "./ProductCard";
import { CategoryFilter } from "./CategoryFilter";
import { LoadingBlock } from "@/components/ui/LoadingBlock";
import { EmptyState } from "@/components/ui/EmptyState";

const NUM_COLUMNS = 2;

export function ProductGrid(): React.JSX.Element {
  const [category, setCategory] = useState<string | null>(null);

  const filter = useMemo(
    () => (category ? { isActive: true, category } : { isActive: true }),
    [category],
  );

  const { data, isLoading, isError } = useDocuments(productSchema, PRODUCTS_COLLECTION_ID, {
    filter,
    sort: "-createdAt",
    limit: 60,
  });

  const products = data?.data ?? [];

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const p of products) {
      if (p.category) set.add(p.category);
    }
    return Array.from(set).sort();
  }, [products]);

  const keyExtractor = useCallback((item: Product) => item._id, []);

  const renderItem = useCallback(
    ({ item }: ListRenderItemInfo<Product>) => (
      <View className="w-1/2 p-1.5">
        <ProductCard product={item} />
      </View>
    ),
    [],
  );

  if (isLoading) {
    return (
      <View className="flex-row flex-wrap px-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <View key={i} className="w-1/2 p-1.5">
            <LoadingBlock className="aspect-square" />
          </View>
        ))}
      </View>
    );
  }

  if (isError) {
    return (
      <View className="px-4">
        <Text className="text-sm text-destructive">Couldn&apos;t load the catalog right now. Pull to refresh.</Text>
      </View>
    );
  }

  return (
    <FlatList
      data={products}
      keyExtractor={keyExtractor}
      renderItem={renderItem}
      numColumns={NUM_COLUMNS}
      contentContainerClassName="px-2.5 pb-8"
      ListHeaderComponent={
        categories.length > 0 ? (
          <View className="pb-4">
            <CategoryFilter categories={categories} value={category} onChange={setCategory} />
          </View>
        ) : null
      }
      ListEmptyComponent={
        <View className="px-2.5">
          <EmptyState message={category ? `No products in "${category}" yet.` : "No products listed yet — check back soon."} />
        </View>
      }
      removeClippedSubviews
      maxToRenderPerBatch={10}
      windowSize={10}
      initialNumToRender={10}
    />
  );
}
