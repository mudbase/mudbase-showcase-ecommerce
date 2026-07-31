import { Pressable, Text, View } from "react-native";
import { router } from "expo-router";
import { formatMoney, formatDate, orderShortId } from "@/lib/format";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import { Button } from "@/components/ui/Button";
import type { Order, OrderStatus } from "@/api/schemas";

const NEXT_STATUS: Partial<Record<OrderStatus, OrderStatus>> = {
  paid: "shipped",
  shipped: "delivered",
};

interface SellerOrderRowProps {
  order: Order;
  onAdvance: (order: Order, nextStatus: OrderStatus) => void;
  isUpdating: boolean;
}

export function SellerOrderRow({ order, onAdvance, isUpdating }: SellerOrderRowProps): React.JSX.Element {
  const nextStatus = NEXT_STATUS[order.orderStatus];

  return (
    <View className="gap-2 border-b border-border py-3 last:border-0">
      <Pressable onPress={() => router.push(`/orders/${order._id}`)} accessibilityRole="button">
        <Text className="font-medium text-foreground">Order #{orderShortId(order._id)}</Text>
        <Text className="text-sm text-muted-foreground">
          {order.shippingName ?? "Customer"} · {formatDate(order.createdAt)}
        </Text>
      </Pressable>
      <View className="flex-row items-center justify-between">
        <Text className="tabular-nums text-foreground">{formatMoney(order.subtotalCents, order.currency)}</Text>
        <OrderStatusBadge status={order.orderStatus} />
      </View>
      {nextStatus && (
        <Button size="sm" variant="outline" isLoading={isUpdating} onPress={() => onAdvance(order, nextStatus)}>
          {`Mark ${nextStatus}`}
        </Button>
      )}
    </View>
  );
}
