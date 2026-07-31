import { Text, View } from "react-native";
import { useCart } from "@/hooks/useCart";
import { formatMoney } from "@/lib/format";
import { Card } from "@/components/ui/Card";
import { Separator } from "@/components/ui/Separator";

export function OrderSummary(): React.JSX.Element {
  const { items, subtotalCents } = useCart();
  const currency = items[0]?.currency ?? "USD";

  return (
    <Card className="gap-3">
      <Text className="font-medium text-foreground">Order summary</Text>
      <View className="gap-2">
        {items.map((item) => (
          <View key={item.productId} className="flex-row justify-between gap-2">
            <Text numberOfLines={1} className="flex-1 text-sm text-muted-foreground">
              {item.name} × {item.quantity}
            </Text>
            <Text className="text-sm tabular-nums text-foreground">{formatMoney(item.priceCents * item.quantity, item.currency)}</Text>
          </View>
        ))}
      </View>
      <Separator />
      <View className="flex-row justify-between">
        <Text className="font-medium text-foreground">Total</Text>
        <Text className="font-medium tabular-nums text-foreground">{formatMoney(subtotalCents, currency)}</Text>
      </View>
    </Card>
  );
}
