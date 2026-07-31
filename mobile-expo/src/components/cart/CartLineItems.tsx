import { FlatList, Pressable, Text, View } from "react-native";
import { Image } from "expo-image";
import { Minus, Plus, X } from "lucide-react-native";
import { useCart } from "@/hooks/useCart";
import { formatMoney } from "@/lib/format";
import { EmptyState } from "@/components/ui/EmptyState";
import type { CartItem } from "@/api/schemas";

export function CartLineItems(): React.JSX.Element {
  const { items, updateQuantity, removeItem } = useCart();

  if (items.length === 0) {
    return <EmptyState message="Your cart is empty." />;
  }

  return (
    <FlatList
      data={items}
      keyExtractor={(item) => item.productId}
      scrollEnabled={false}
      ItemSeparatorComponent={() => <View className="h-px bg-border" />}
      renderItem={({ item }: { item: CartItem }) => (
        <View className="flex-row items-center gap-3 py-4">
          <View className="h-16 w-16 shrink-0 overflow-hidden rounded-md bg-muted">
            {item.imageUrl && <Image source={item.imageUrl} style={{ width: 64, height: 64 }} contentFit="cover" />}
          </View>
          <View className="min-w-0 flex-1">
            <Text numberOfLines={1} className="font-medium text-foreground">
              {item.name}
            </Text>
            <Text className="text-sm tabular-nums text-muted-foreground">{formatMoney(item.priceCents, item.currency)}</Text>
          </View>
          <View className="flex-row items-center rounded-md border border-border">
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`Decrease quantity of ${item.name}`}
              hitSlop={8}
              onPress={() => void updateQuantity(item.productId, item.quantity - 1)}
              className="h-8 w-8 items-center justify-center active:bg-secondary"
            >
              <Minus size={12} color="#211d1a" />
            </Pressable>
            <Text className="w-6 text-center text-sm tabular-nums text-foreground">{item.quantity}</Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`Increase quantity of ${item.name}`}
              hitSlop={8}
              onPress={() => void updateQuantity(item.productId, item.quantity + 1)}
              className="h-8 w-8 items-center justify-center active:bg-secondary"
            >
              <Plus size={12} color="#211d1a" />
            </Pressable>
          </View>
          <Text className="w-16 text-right font-medium tabular-nums text-foreground">
            {formatMoney(item.priceCents * item.quantity, item.currency)}
          </Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Remove ${item.name} from cart`}
            hitSlop={8}
            onPress={() => void removeItem(item.productId)}
          >
            <X size={16} color="#6b615a" />
          </Pressable>
        </View>
      )}
    />
  );
}
