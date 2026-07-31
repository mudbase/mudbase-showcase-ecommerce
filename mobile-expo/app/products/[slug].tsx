import { useEffect } from "react";
import { ScrollView, Text, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { z } from "zod";
import { SafeAreaView } from "react-native-safe-area-context";
import { useDocuments } from "@/hooks/useCollection";
import { PRODUCTS_COLLECTION_ID } from "@/config/env";
import { productSchema } from "@/api/schemas";
import { formatMoney, discountPercent } from "@/lib/format";
import { parseJsonField } from "@/lib/jsonField";
import { ImageCarousel } from "@/components/catalog/ImageCarousel";
import { AddToCartForm } from "@/components/catalog/AddToCartForm";
import { Badge } from "@/components/ui/Badge";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

const paramsSchema = z.object({ slug: z.string().min(1) });

export default function ProductDetailScreen(): React.JSX.Element {
  // All hooks run unconditionally on every render (Rules of Hooks) — an
  // invalid/missing slug param redirects via an effect instead of an early
  // return, and the query is simply disabled until the param is valid.
  const params = useLocalSearchParams();
  const parsed = paramsSchema.safeParse(params);
  const slug = parsed.success ? parsed.data.slug : "";

  const { data, isLoading, isError } = useDocuments(
    productSchema,
    PRODUCTS_COLLECTION_ID,
    { filter: { slug } },
    { enabled: parsed.success },
  );

  useEffect(() => {
    if (!parsed.success) router.replace("/(tabs)");
  }, [parsed.success]);

  const product = data?.data[0];

  if (!parsed.success || isLoading) {
    return (
      <SafeAreaView className="flex-1 bg-background">
        <View className="gap-4 p-4">
          <LoadingBlock className="aspect-square w-full" />
          <LoadingBlock className="h-8 w-2/3" />
          <LoadingBlock className="h-6 w-1/3" />
        </View>
      </SafeAreaView>
    );
  }

  if (isError || !product) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background">
        <Text className="text-muted-foreground">This product isn&apos;t available anymore.</Text>
      </SafeAreaView>
    );
  }

  const gallery = parseJsonField<string[]>(product.galleryJson, []);
  const images = [product.imageUrl, ...gallery].filter((url): url is string => Boolean(url));
  const percentOff = discountPercent(product.priceCents, product.compareAtPriceCents);

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="gap-6 p-4">
        <ImageCarousel images={images} alt={product.name} />

        <View className="gap-3">
          <View className="flex-row items-center gap-2">
            {product.category && <Badge variant="secondary">{product.category}</Badge>}
            {percentOff !== null && <Badge>{`${percentOff}% off`}</Badge>}
          </View>
          <Text className="font-semibold text-2xl text-foreground">{product.name}</Text>
          <View className="flex-row items-baseline gap-2">
            <Text className="text-xl font-semibold tabular-nums text-foreground">
              {formatMoney(product.priceCents, product.currency)}
            </Text>
            {percentOff !== null && (
              <Text className="tabular-nums text-muted-foreground line-through">
                {formatMoney(product.compareAtPriceCents as number, product.currency)}
              </Text>
            )}
          </View>
        </View>

        {product.description && <Text className="leading-relaxed text-muted-foreground">{product.description}</Text>}

        <AddToCartForm product={product} />

        <Text className="text-sm text-muted-foreground">
          {product.stock > 0 ? `${product.stock} in stock` : "Currently out of stock"}
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}
