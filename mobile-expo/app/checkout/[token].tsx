import { ScrollView, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { z } from "zod";
import { SafeAreaView } from "react-native-safe-area-context";
import { PaymentLinkPanel } from "@/components/checkout/PaymentLinkPanel";

const paramsSchema = z.object({ token: z.string().min(1) });

export default function PaymentScreen(): React.JSX.Element {
  const parsed = paramsSchema.safeParse(useLocalSearchParams());

  return (
    <SafeAreaView className="flex-1 bg-background">
      <ScrollView contentContainerClassName="gap-6 p-4">
        <Text className="text-center font-semibold text-2xl text-foreground">Pay for your order</Text>
        {parsed.success ? (
          <PaymentLinkPanel token={parsed.data.token} />
        ) : (
          <View className="items-center py-16">
            <Text className="text-muted-foreground">This payment link is missing or malformed.</Text>
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
