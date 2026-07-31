import { ScrollView, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useCart } from "@/hooks/useCart";
import { CartLineItems } from "@/components/cart/CartLineItems";
import { CartSummary } from "@/components/cart/CartSummary";
import { LoadingBlock } from "@/components/ui/LoadingBlock";

export default function CartScreen(): React.JSX.Element {
  const { isLoading, requiresCustomerAccount } = useCart();

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <ScrollView contentContainerClassName="gap-6 p-4">
        <Text className="font-semibold text-2xl text-foreground">Your cart</Text>
        {requiresCustomerAccount ? (
          <Text className="text-sm text-muted-foreground">
            Signed in as a seller — sign in with a customer account to shop.
          </Text>
        ) : isLoading ? (
          <LoadingBlock className="h-40" />
        ) : (
          <>
            <CartLineItems />
            <CartSummary />
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
