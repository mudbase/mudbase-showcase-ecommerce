import { FlatList, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useDocuments } from "@/hooks/useCollection";
import { useAuth } from "@/hooks/useAuth";
import { ORDERS_COLLECTION_ID } from "@/config/env";
import { orderSchema, type Order } from "@/api/schemas";
import { OrderListItem } from "@/components/orders/OrderListItem";
import { EmptyState } from "@/components/ui/EmptyState";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

export default function OrdersScreen(): React.JSX.Element {
  const { user } = useAuth();
  const userId = user?.id;

  const { data, isLoading, isError } = useDocuments(
    orderSchema,
    ORDERS_COLLECTION_ID,
    { filter: { userId }, sort: "-createdAt" },
    { enabled: !!userId },
  );

  const orders = data?.data ?? [];

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <View className="px-4 pb-2 pt-2">
        <Text className="font-semibold text-2xl text-foreground">Your orders</Text>
      </View>
      {isLoading ? (
        <View className="gap-2 px-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <LoadingBlock key={i} className="h-16" />
          ))}
        </View>
      ) : isError ? (
        <Text className="px-4 text-sm text-destructive">Couldn&apos;t load your orders right now.</Text>
      ) : (
        <FlatList
          data={orders}
          keyExtractor={(order: Order) => order._id}
          contentContainerClassName="px-4 pb-8"
          ItemSeparatorComponent={() => <View className="h-px bg-border" />}
          renderItem={({ item }: { item: Order }) => <OrderListItem order={item} />}
          ListEmptyComponent={<EmptyState message="No orders yet." />}
        />
      )}
    </SafeAreaView>
  );
}
