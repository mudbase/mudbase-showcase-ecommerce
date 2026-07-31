import { Text, View, type ColorValue } from "react-native";
import { Tabs } from "expo-router";
import { Home, PackageSearch, ShoppingBag, User } from "lucide-react-native";
import { useCart } from "@/hooks/useCart";

const FALLBACK_ICON_COLOR = "#211d1a";

/**
 * `Tabs.Screen`'s `tabBarIcon` hands back React Navigation's broader
 * `ColorValue` (which also covers platform-specific opaque color refs), while
 * lucide-react-native icons only accept a plain `string`. Every tint color
 * this app configures (`tabBarActiveTintColor`/`tabBarInactiveTintColor`
 * below) is always a literal hex string, so this narrows safely without a cast.
 */
function toIconColor(color: ColorValue): string {
  return typeof color === "string" ? color : FALLBACK_ICON_COLOR;
}

function CartIcon({ color, size }: { color: string; size: number }): React.JSX.Element {
  const { items } = useCart();
  const count = items.reduce((sum, i) => sum + i.quantity, 0);
  return (
    <View>
      <ShoppingBag color={color} size={size} />
      {count > 0 && (
        <View className="absolute -right-2 -top-2 h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1">
          <Text className="text-[10px] font-semibold text-white">{count}</Text>
        </View>
      )}
    </View>
  );
}

export default function TabsLayout(): React.JSX.Element {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#145c3f",
        tabBarInactiveTintColor: "#6b615a",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: "Home", tabBarIcon: ({ color, size }) => <Home color={toIconColor(color)} size={size} /> }}
      />
      <Tabs.Screen
        name="cart"
        options={{ title: "Cart", tabBarIcon: ({ color, size }) => <CartIcon color={toIconColor(color)} size={size} /> }}
      />
      <Tabs.Screen
        name="orders"
        options={{
          title: "Orders",
          tabBarIcon: ({ color, size }) => <PackageSearch color={toIconColor(color)} size={size} />,
        }}
      />
      <Tabs.Screen
        name="account"
        options={{ title: "Account", tabBarIcon: ({ color, size }) => <User color={toIconColor(color)} size={size} /> }}
      />
    </Tabs>
  );
}
