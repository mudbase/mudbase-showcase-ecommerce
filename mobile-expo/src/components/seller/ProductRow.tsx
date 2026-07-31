import { Alert, Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { Pencil, Trash2 } from "lucide-react-native";
import { formatMoney, discountPercent } from "@/lib/format";
import { Badge } from "@/components/ui/Badge";
import type { Product } from "@/api/schemas";

interface ProductRowProps {
  product: Product;
  onDelete: (productId: string) => void;
  isDeleting: boolean;
}

export function ProductRow({ product, onDelete, isDeleting }: ProductRowProps): React.JSX.Element {
  const percentOff = discountPercent(product.priceCents, product.compareAtPriceCents);

  const confirmDelete = (): void => {
    Alert.alert("Delete product", `Delete "${product.name}"? This can't be undone.`, [
      { text: "Cancel", style: "cancel" },
      { text: "Delete", style: "destructive", onPress: () => onDelete(product._id) },
    ]);
  };

  return (
    <View className="flex-row items-center justify-between gap-3 border-b border-border py-3 last:border-0">
      <View className="min-w-0 flex-1">
        <Text numberOfLines={1} className="font-medium text-foreground">
          {product.name}
        </Text>
        <View className="mt-1 flex-row items-center gap-2">
          {percentOff !== null && (
            <Text className="text-xs tabular-nums text-muted-foreground line-through">
              {formatMoney(product.compareAtPriceCents as number, product.currency)}
            </Text>
          )}
          <Text className="text-sm tabular-nums text-foreground">{formatMoney(product.priceCents, product.currency)}</Text>
          <Text className="text-xs tabular-nums text-muted-foreground">· {product.stock} in stock</Text>
        </View>
        <View className="mt-1">
          <Badge variant={product.isActive ? "success" : "secondary"}>{product.isActive ? "Active" : "Hidden"}</Badge>
        </View>
      </View>
      <View className="flex-row gap-1">
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Edit ${product.name}`}
          onPress={() => router.push(`/seller/products/${product._id}/edit`)}
          className="h-9 w-9 items-center justify-center rounded-md active:bg-secondary"
        >
          <Pencil size={16} color="#211d1a" />
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Delete ${product.name}`}
          onPress={confirmDelete}
          disabled={isDeleting}
          className="h-9 w-9 items-center justify-center rounded-md active:bg-secondary"
        >
          <Trash2 size={16} color="#c53021" />
        </Pressable>
      </View>
    </View>
  );
}
