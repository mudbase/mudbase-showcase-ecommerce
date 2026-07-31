import { memo } from "react";
import { Pressable, Text, View } from "react-native";
import { Image } from "expo-image";
import { router } from "expo-router";
import { formatMoney, discountPercent } from "@/lib/format";
import { Badge } from "@/components/ui/Badge";
import type { Product } from "@/api/schemas";

interface ProductCardProps {
  product: Product;
}

/**
 * No hover-cycle gallery preview here (unlike web's ProductCard) — there is no
 * hover state on a touchscreen. The full gallery lives on the product detail
 * screen's ImageCarousel instead, which is the honest touch-first equivalent.
 */
function ProductCardImpl({ product }: ProductCardProps): React.JSX.Element {
  const outOfStock = product.stock <= 0;
  const percentOff = discountPercent(product.priceCents, product.compareAtPriceCents);

  return (
    <Pressable
      onPress={() => router.push(`/products/${product.slug}`)}
      className="w-full overflow-hidden rounded-lg border border-border bg-card active:opacity-90"
      accessibilityRole="button"
      accessibilityLabel={product.name}
    >
      <View className="aspect-square w-full bg-muted">
        {product.imageUrl ? (
          <Image
            source={product.imageUrl}
            style={{ width: "100%", height: "100%" }}
            contentFit="cover"
            transition={150}
            cachePolicy="memory-disk"
          />
        ) : (
          <View className="h-full w-full items-center justify-center">
            <Text className="text-xs text-muted-foreground">No image</Text>
          </View>
        )}
        <View className="absolute left-2 top-2 flex-row gap-1">
          {outOfStock && <Badge variant="secondary">Out of stock</Badge>}
          {percentOff !== null && <Badge>{`${percentOff}% off`}</Badge>}
        </View>
      </View>
      <View className="p-3">
        <Text className="text-xs uppercase tracking-wide text-muted-foreground">{product.category || "General"}</Text>
        <Text numberOfLines={1} className="mt-1 font-medium text-foreground">
          {product.name}
        </Text>
        <View className="mt-1 flex-row items-baseline gap-2">
          <Text className="font-semibold tabular-nums text-foreground">{formatMoney(product.priceCents, product.currency)}</Text>
          {percentOff !== null && (
            <Text className="text-xs tabular-nums text-muted-foreground line-through">
              {formatMoney(product.compareAtPriceCents as number, product.currency)}
            </Text>
          )}
        </View>
      </View>
    </Pressable>
  );
}

export const ProductCard = memo(ProductCardImpl);
