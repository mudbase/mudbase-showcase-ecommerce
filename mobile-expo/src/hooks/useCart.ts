import { useCallback, useMemo } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { mudbaseClient } from "@/api/client";
import { CARTS_COLLECTION_ID } from "@/config/env";
import { useAuth } from "./useAuth";
import { parseJsonField, stringifyJsonField } from "@/lib/jsonField";
import { cartSchema, type Cart, type CartItem } from "@/api/schemas";

interface UseCartReturn {
  items: CartItem[];
  subtotalCents: number;
  isLoading: boolean;
  /** True when the signed-in account is not a `customer` — cart writes only exist for that role. */
  requiresCustomerAccount: boolean;
  addItem: (item: Omit<CartItem, "quantity">, quantity?: number) => Promise<void>;
  updateQuantity: (productId: string, quantity: number) => Promise<void>;
  removeItem: (productId: string) => Promise<void>;
  clear: () => Promise<void>;
}

/**
 * Server-persisted cart only — this mobile version requires signing in before
 * browsing (see README "Deviations from the web version"), so there is no
 * guest/localStorage cart branch to merge on registration the way
 * web/src/hooks/useCart.ts has to. One document per user; Mudbase collections
 * have no native upsert, so this reads the caller's cart, then creates or
 * updates depending on whether one already exists — same pattern the web app
 * uses, documented as a real platform constraint in README "Known limitations".
 */
export function useCart(): UseCartReturn {
  const { user, isCustomer } = useAuth();
  const queryClient = useQueryClient();
  const userId = user?.id;

  const cartQuery = useQuery({
    queryKey: ["cart", userId],
    queryFn: async (): Promise<Cart | null> => {
      const res = await mudbaseClient.listDocuments(cartSchema, CARTS_COLLECTION_ID, { filter: { userId } });
      return res.data[0] ?? null;
    },
    enabled: isCustomer && !!userId,
  });

  const items = useMemo(() => parseJsonField<CartItem[]>(cartQuery.data?.itemsJson, []), [cartQuery.data]);

  const persist = useMutation({
    mutationFn: async (nextItems: CartItem[]): Promise<Cart> => {
      if (!userId) throw new Error("A customer account is required to use the cart.");
      const itemsJson = stringifyJsonField(nextItems);
      // Re-fetch right before deciding create-vs-update rather than trusting the
      // query cache, which can still be undefined immediately after sign-in —
      // same race the web app's useCart.ts documents and guards against.
      const res = await mudbaseClient.listDocuments(cartSchema, CARTS_COLLECTION_ID, { filter: { userId } });
      const existing = res.data[0] ?? null;
      if (existing) {
        return mudbaseClient.updateDocument(cartSchema, CARTS_COLLECTION_ID, existing._id, { itemsJson });
      }
      return mudbaseClient.createDocument(cartSchema, CARTS_COLLECTION_ID, { userId, itemsJson });
    },
    onSuccess: (doc) => {
      queryClient.setQueryData(["cart", userId], doc);
    },
  });

  const addItem = useCallback(
    async (item: Omit<CartItem, "quantity">, quantity = 1): Promise<void> => {
      const next = [...items];
      const existingIndex = next.findIndex((i) => i.productId === item.productId);
      const existing = existingIndex >= 0 ? next[existingIndex] : undefined;
      if (existingIndex >= 0 && existing) {
        next[existingIndex] = { ...existing, quantity: existing.quantity + quantity };
      } else {
        next.push({ ...item, quantity });
      }
      await persist.mutateAsync(next);
    },
    [items, persist],
  );

  const updateQuantity = useCallback(
    async (productId: string, quantity: number): Promise<void> => {
      const next =
        quantity <= 0
          ? items.filter((i) => i.productId !== productId)
          : items.map((i) => (i.productId === productId ? { ...i, quantity } : i));
      await persist.mutateAsync(next);
    },
    [items, persist],
  );

  const removeItem = useCallback(
    async (productId: string): Promise<void> => {
      await persist.mutateAsync(items.filter((i) => i.productId !== productId));
    },
    [items, persist],
  );

  const clear = useCallback(async (): Promise<void> => {
    await persist.mutateAsync([]);
  }, [persist]);

  const subtotalCents = items.reduce((sum, i) => sum + i.priceCents * i.quantity, 0);

  return {
    items,
    subtotalCents,
    isLoading: isCustomer ? cartQuery.isPending : false,
    requiresCustomerAccount: !isCustomer,
    addItem,
    updateQuantity,
    removeItem,
    clear,
  };
}
