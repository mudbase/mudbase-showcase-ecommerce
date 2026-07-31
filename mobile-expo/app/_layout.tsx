import "../global.css";
import { useEffect } from "react";
import { ActivityIndicator, View } from "react-native";
import { Stack, useRouter, useSegments } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { AppProviders } from "@/providers/AppProviders";
import { useAuthStore } from "@/stores/authStore";
import { useAuth } from "@/hooks/useAuth";

/**
 * This mobile version requires signing in (as a customer or seller) before
 * browsing — unlike the web reference app's anonymous-guest-first flow. See
 * README "Deviations from the web version" for why: it removes an entire
 * guest-cart/localStorage-merge code path (web/src/hooks/useCart.ts's
 * migrateGuestCartToServer) for a simpler, equally real mobile flow, since
 * Mudbase's `authenticated`-role read permission is satisfied by any signed-in
 * customRole just as well as by an anonymous session.
 */
function AuthGuard(): null {
  const { user, isInitializing } = useAuth();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    if (isInitializing) return;
    const inAuthGroup = segments[0] === "(auth)";
    if (!user && !inAuthGroup) {
      router.replace("/(auth)/login");
    } else if (user && inAuthGroup) {
      router.replace("/(tabs)");
    }
  }, [user, isInitializing, segments, router]);

  return null;
}

function BootSplash(): React.JSX.Element {
  return (
    <View className="flex-1 items-center justify-center bg-background">
      <ActivityIndicator size="large" color="#145c3f" />
    </View>
  );
}

function RootNavigator(): React.JSX.Element {
  const isInitializing = useAuthStore((s) => s.isInitializing);

  useEffect(() => {
    void useAuthStore.getState().initialize();
  }, []);

  if (isInitializing) return <BootSplash />;

  return (
    <>
      <AuthGuard />
      <StatusBar style="auto" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="products/[slug]" options={{ headerShown: true, title: "" }} />
        <Stack.Screen name="checkout/index" options={{ headerShown: true, title: "Checkout" }} />
        <Stack.Screen name="checkout/[token]" options={{ headerShown: true, title: "Payment" }} />
        <Stack.Screen name="orders/[id]" options={{ headerShown: true, title: "Order" }} />
        <Stack.Screen name="seller" />
      </Stack>
    </>
  );
}

export default function RootLayout(): React.JSX.Element {
  return (
    <AppProviders>
      <RootNavigator />
    </AppProviders>
  );
}
