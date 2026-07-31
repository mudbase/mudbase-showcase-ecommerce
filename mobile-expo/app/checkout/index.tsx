import { useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { router } from "expo-router";
import * as Linking from "expo-linking";
import { SafeAreaView } from "react-native-safe-area-context";
import { useCart } from "@/hooks/useCart";
import { useAuth } from "@/hooks/useAuth";
import { mudbaseClient } from "@/api/client";
import { createOrderPaymentLink } from "@/api/checkoutClient";
import { ORDERS_COLLECTION_ID } from "@/config/env";
import { orderSchema, type Order, type ShippingAddress } from "@/api/schemas";
import { stringifyJsonField } from "@/lib/jsonField";
import { ShippingForm } from "@/components/checkout/ShippingForm";
import { OrderSummary } from "@/components/checkout/OrderSummary";
import { ErrorNotice } from "@/components/ui/ErrorNotice";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

/**
 * Payment amount/currency/network are fixed to match the web reference app's
 * checkout exactly (web/src/app/checkout/page.tsx) — Mudbase Payment Links in
 * this demo settle in USDC on Polygon.
 */
const PAYMENT_CURRENCY = "USDC";
const PAYMENT_NETWORK = "POLYGON";

export default function CheckoutScreen(): React.JSX.Element {
  const { user } = useAuth();
  const { items, subtotalCents, clear, isLoading: cartLoading } = useCart();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const placeOrder = async (address: ShippingAddress): Promise<void> => {
    if (!user) return;
    setSubmitting(true);
    setError(null);
    try {
      const amount = (subtotalCents / 100).toFixed(2);

      const order: Order = await mudbaseClient.createDocument(orderSchema, ORDERS_COLLECTION_ID, {
        userId: user.id,
        itemsJson: stringifyJsonField(items.map((i) => ({ productId: i.productId, name: i.name, priceCents: i.priceCents, quantity: i.quantity }))),
        subtotalCents,
        currency: "USD",
        orderStatus: "awaiting_payment",
        shippingName: address.fullName,
        shippingAddressJson: stringifyJsonField(address),
        paymentStatus: "unpaid",
      });

      const redirectUrl = Linking.createURL(`/orders/${order._id}`);

      const result = await createOrderPaymentLink({
        orderId: order._id,
        amount,
        currency: PAYMENT_CURRENCY,
        network: PAYMENT_NETWORK,
        redirectUrl,
      });

      if (!result.ok) {
        // No payment link could be created for ANY failure reason (kyc_required,
        // merchant auth failure, or an unknown/5xx from the proxy — e.g. this demo
        // org's undocumented-to-the-client "no payment merchant configured" 502) —
        // roll the order back to "pending" in every case, not just kyc_required.
        // Leaving it at "awaiting_payment" with no paymentLinkToken is a stuck,
        // unrecoverable order: it can never reach a payment screen (no token to
        // navigate to) and never re-attempts checkout (payment already "in
        // progress" from the order's own perspective).
        await mudbaseClient.updateDocument(orderSchema, ORDERS_COLLECTION_ID, order._id, { orderStatus: "pending" });
        setError(result.message);
        return;
      }

      await mudbaseClient.updateDocument(orderSchema, ORDERS_COLLECTION_ID, order._id, { paymentLinkToken: result.token });
      await clear();
      router.replace(`/checkout/${result.token}`);
    } catch {
      setError("Something went wrong placing your order. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  if (cartLoading) {
    return (
      <SafeAreaView className="flex-1 bg-background">
        <LoadingBlock className="m-4 h-40" />
      </SafeAreaView>
    );
  }

  if (items.length === 0) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background px-6">
        <Text className="text-center text-muted-foreground">Your cart is empty — add something before checking out.</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="gap-6 p-4">
        <View className="gap-1">
          <Text className="font-semibold text-2xl text-foreground">Checkout</Text>
        </View>
        {error && <ErrorNotice message={error} />}
        <ShippingForm onSubmit={placeOrder} submitting={submitting} />
        <OrderSummary />
      </ScrollView>
    </SafeAreaView>
  );
}
