import { useEffect } from "react";
import { Stack, router } from "expo-router";
import { useAuth } from "@/hooks/useAuth";

/**
 * UX-level gating only — real authorization is enforced server-side by
 * Mudbase's collection permissions (seller role → unconditional read/update
 * on `orders`, full CRUD on `products`; a customer token gets a real 403 on
 * these same calls). Mirrors web/src/components/seller/SellerGuard.tsx.
 */
export default function SellerLayout(): React.JSX.Element | null {
  const { isSeller, isInitializing } = useAuth();

  useEffect(() => {
    if (!isInitializing && !isSeller) {
      router.replace("/(tabs)");
    }
  }, [isInitializing, isSeller]);

  if (isInitializing || !isSeller) return null;

  return (
    <Stack screenOptions={{ headerShown: true }}>
      <Stack.Screen name="index" options={{ title: "Seller dashboard" }} />
      <Stack.Screen name="products/new" options={{ title: "Add product" }} />
      <Stack.Screen name="products/[id]/edit" options={{ title: "Edit product" }} />
    </Stack>
  );
}
