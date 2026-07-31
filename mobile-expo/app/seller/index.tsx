import { ScrollView, Text, View } from "react-native";
import { router } from "expo-router";
import { useDocuments, useUpdateDocument, useDeleteDocument } from "@/hooks/useCollection";
import { ORDERS_COLLECTION_ID, PRODUCTS_COLLECTION_ID } from "@/config/env";
import { orderSchema, productSchema, type Order, type OrderStatus, type Product } from "@/api/schemas";
import { SellerOrderRow } from "@/components/seller/SellerOrderRow";
import { ProductRow } from "@/components/seller/ProductRow";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

const ORDER_QUEUE_POLL_MS = 5000;

export default function SellerDashboardScreen(): React.JSX.Element {
  // Web's seller dashboard subscribes to a Socket.IO room for live order
  // updates (web/src/hooks/useOrdersLive.ts). socket.io-client needs extra
  // native polyfills to run on React Native/Hermes that aren't worth the
  // dependency weight for this reference app, so this screen polls instead —
  // a deliberate simplification, not a Mudbase platform limitation (see
  // README "Deviations from the web version").
  const ordersQuery = useDocuments(
    orderSchema,
    ORDERS_COLLECTION_ID,
    { sort: "-createdAt", limit: 100 },
    { refetchInterval: ORDER_QUEUE_POLL_MS },
  );
  const updateOrder = useUpdateDocument(orderSchema, ORDERS_COLLECTION_ID);

  const productsQuery = useDocuments(productSchema, PRODUCTS_COLLECTION_ID, { sort: "-createdAt", limit: 100 });
  const deleteProduct = useDeleteDocument(PRODUCTS_COLLECTION_ID);

  const orders = ordersQuery.data?.data ?? [];
  const products = productsQuery.data?.data ?? [];

  const handleAdvance = (order: Order, nextStatus: OrderStatus): void => {
    updateOrder.mutate({ documentId: order._id, data: { orderStatus: nextStatus } });
  };

  return (
    <ScrollView className="flex-1 bg-background" contentContainerClassName="gap-10 p-4">
      <View>
        <Text className="mb-1 font-semibold text-xl text-foreground">Orders</Text>
        <Text className="mb-4 text-sm text-muted-foreground">Refreshes automatically every few seconds.</Text>
        {ordersQuery.isLoading ? (
          <LoadingBlock className="h-48" />
        ) : ordersQuery.isError ? (
          <Text className="text-sm text-destructive">Couldn&apos;t load orders.</Text>
        ) : orders.length === 0 ? (
          <EmptyState message="No orders yet — they'll appear here once one comes in." />
        ) : (
          <View>
            {orders.map((order) => (
              <SellerOrderRow
                key={order._id}
                order={order}
                onAdvance={handleAdvance}
                isUpdating={updateOrder.isPending && updateOrder.variables?.documentId === order._id}
              />
            ))}
          </View>
        )}
      </View>

      <View>
        <View className="mb-4 flex-row items-center justify-between">
          <Text className="font-semibold text-xl text-foreground">Products</Text>
          <Button size="sm" onPress={() => router.push("/seller/products/new")}>
            Add product
          </Button>
        </View>
        {productsQuery.isLoading ? (
          <LoadingBlock className="h-48" />
        ) : productsQuery.isError ? (
          <Text className="text-sm text-destructive">Couldn&apos;t load products.</Text>
        ) : products.length === 0 ? (
          <EmptyState message="No products listed yet." />
        ) : (
          <View>
            {products.map((product: Product) => (
              <ProductRow
                key={product._id}
                product={product}
                onDelete={(productId) => deleteProduct.mutate(productId)}
                isDeleting={deleteProduct.isPending && deleteProduct.variables === product._id}
              />
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}
