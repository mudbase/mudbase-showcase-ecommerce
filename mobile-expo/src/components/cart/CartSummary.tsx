import { Text, View } from "react-native";
import { router } from "expo-router";
import { useCart } from "@/hooks/useCart";
import { formatMoney } from "@/lib/format";
import { Button } from "@/components/ui/Button";
import { Separator } from "@/components/ui/Separator";
import { Card } from "@/components/ui/Card";

export function CartSummary(): React.JSX.Element {
  const { items, subtotalCents, requiresCustomerAccount } = useCart();
  const currency = items[0]?.currency ?? "USD";

  return (
    <Card className="gap-4">
      <Text className="font-medium text-foreground">Order summary</Text>
      <View className="flex-row justify-between">
        <Text className="text-sm text-muted-foreground">Subtotal</Text>
        <Text className="text-sm tabular-nums text-foreground">{formatMoney(subtotalCents, currency)}</Text>
      </View>
      <Separator />
      <View className="flex-row justify-between">
        <Text className="font-medium text-foreground">Total</Text>
        <Text className="font-medium tabular-nums text-foreground">{formatMoney(subtotalCents, currency)}</Text>
      </View>
      <Button
        onPress={() => router.push("/checkout")}
        disabled={items.length === 0 || requiresCustomerAccount}
      >
        Checkout
      </Button>
    </Card>
  );
}
