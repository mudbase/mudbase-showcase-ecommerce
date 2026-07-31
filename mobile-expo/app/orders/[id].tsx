import { useEffect } from "react";
import { ScrollView, Text, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { z } from "zod";
import { SafeAreaView } from "react-native-safe-area-context";
import { useDocument } from "@/hooks/useCollection";
import { ORDERS_COLLECTION_ID } from "@/config/env";
import { orderSchema, orderLineItemSchema, shippingAddressSchema } from "@/api/schemas";
import { formatMoney, formatDate, orderShortId } from "@/lib/format";
import { parseJsonField } from "@/lib/jsonField";
import { OrderStatusBadge } from "@/components/orders/OrderStatusBadge";
import { OrderTimeline } from "@/components/orders/OrderTimeline";
import { OrderItemsTable } from "@/components/orders/OrderItemsTable";
import { Separator } from "@/components/ui/Separator";
import { Button } from "@/components/ui/Button";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

const paramsSchema = z.object({ id: z.string().min(1) });

export default function OrderDetailScreen(): React.JSX.Element {
  const params = useLocalSearchParams();
  const parsed = paramsSchema.safeParse(params);
  const id = parsed.success ? parsed.data.id : undefined;

  const { data: order, isLoading, isError } = useDocument(orderSchema, ORDERS_COLLECTION_ID, id);

  useEffect(() => {
    if (!parsed.success) router.replace("/(tabs)/orders");
  }, [parsed.success]);

  if (!parsed.success || isLoading) {
    return (
      <SafeAreaView className="flex-1 bg-background">
        <LoadingBlock className="m-4 h-64" />
      </SafeAreaView>
    );
  }

  if (isError || !order) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background">
        <Text className="text-muted-foreground">This order couldn&apos;t be found.</Text>
      </SafeAreaView>
    );
  }

  const items = z.array(orderLineItemSchema).parse(parseJsonField(order.itemsJson, []));
  const address = order.shippingAddressJson
    ? shippingAddressSchema.safeParse(parseJsonField(order.shippingAddressJson, null)).data ?? null
    : null;

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="gap-6 p-4">
        <View className="flex-row items-center justify-between">
          <View>
            <Text className="font-semibold text-xl text-foreground">Order #{orderShortId(order._id)}</Text>
            <Text className="text-sm text-muted-foreground">{formatDate(order.createdAt)}</Text>
          </View>
          <OrderStatusBadge status={order.orderStatus} />
        </View>

        <OrderTimeline status={order.orderStatus} />

        <Separator />

        <View>
          <Text className="mb-3 font-medium text-foreground">Items</Text>
          <OrderItemsTable items={items} currency={order.currency} />
          <View className="mt-3 flex-row justify-between">
            <Text className="font-medium text-foreground">Total</Text>
            <Text className="font-medium tabular-nums text-foreground">{formatMoney(order.subtotalCents, order.currency)}</Text>
          </View>
        </View>

        {address && (
          <View>
            <Text className="mb-2 font-medium text-foreground">Shipping to</Text>
            <Text className="text-sm leading-relaxed text-muted-foreground">
              {address.fullName}
              {"\n"}
              {address.line1}
              {address.line2 ? `, ${address.line2}` : ""}
              {"\n"}
              {address.city}, {address.region} {address.postalCode}
              {"\n"}
              {address.country}
            </Text>
          </View>
        )}

        {order.paymentLinkToken && order.paymentStatus !== "paid" && (
          <Button onPress={() => router.push(`/checkout/${order.paymentLinkToken}`)}>Complete payment</Button>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
