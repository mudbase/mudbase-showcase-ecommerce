import { Text, View } from "react-native";
import { formatMoney } from "@/lib/format";
import type { OrderLineItem } from "@/api/schemas";

export function OrderItemsTable({ items, currency }: { items: OrderLineItem[]; currency: string }): React.JSX.Element {
  return (
    <View className="gap-2">
      <View className="flex-row justify-between border-b border-border pb-2">
        <Text className="flex-1 text-xs text-muted-foreground">Item</Text>
        <Text className="w-10 text-right text-xs text-muted-foreground">Qty</Text>
        <Text className="w-20 text-right text-xs text-muted-foreground">Total</Text>
      </View>
      {items.map((item) => (
        <View key={item.productId} className="flex-row justify-between border-b border-border py-2 last:border-0">
          <Text numberOfLines={1} className="flex-1 text-sm text-foreground">
            {item.name}
          </Text>
          <Text className="w-10 text-right text-sm tabular-nums text-foreground">{item.quantity}</Text>
          <Text className="w-20 text-right text-sm tabular-nums text-foreground">
            {formatMoney(item.priceCents * item.quantity, currency)}
          </Text>
        </View>
      ))}
    </View>
  );
}
