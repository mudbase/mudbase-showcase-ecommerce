import { Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { ProductGrid } from "@/components/catalog/ProductGrid";

export default function HomeScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <View className="gap-1 px-4 pb-4 pt-2">
        <Text className="font-semibold text-2xl text-foreground">Commonwealth Goods</Text>
        <Text className="text-sm text-muted-foreground">
          Every product, order, cart, and payment here is served by a real Mudbase project — no custom backend.
        </Text>
      </View>
      <ProductGrid />
    </SafeAreaView>
  );
}
