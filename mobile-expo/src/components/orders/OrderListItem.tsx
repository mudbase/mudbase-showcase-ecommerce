import { Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { formatMoney, formatDate, orderShortId } from "@/lib/format";
import { OrderStatusBadge } from "./OrderStatusBadge";
import type { Order } from "@/api/schemas";

export function OrderListItem({ order }: { order: Order }): React.JSX.Element {
  return (
    <Pressable
      onPress={() => router.push(`/orders/${order._id}`)}
      accessibilityRole="button"
      className="flex-row items-center justify-between gap-3 py-4 active:opacity-70"
    >
      <View className="min-w-0 flex-1">
        <Text className="font-medium text-foreground">Order #{orderShortId(order._id)}</Text>
        <Text className="text-sm text-muted-foreground">{formatDate(order.createdAt)}</Text>
      </View>
      <Text className="tabular-nums text-foreground">{formatMoney(order.subtotalCents, order.currency)}</Text>
      <OrderStatusBadge status={order.orderStatus} />
    </Pressable>
  );
}
