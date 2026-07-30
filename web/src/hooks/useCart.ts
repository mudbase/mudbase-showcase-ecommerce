"use client"

import { useCallback, useMemo } from "react"
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { parseJsonField, stringifyJsonField } from "@/lib/json-field"
import { CARTS_COLLECTION_ID } from "@/lib/config"
import type { Cart, CartItem } from "@/types/cart"

const GUEST_CART_STORAGE_KEY = "mudbase_showcase_guest_cart"

interface UseCartReturn {
  items: CartItem[]
  subtotalCents: number
  isLoading: boolean
  addItem: (item: Omit<CartItem, "quantity">, quantity?: number) => Promise<void>
  updateQuantity: (productId: string, quantity: number) => Promise<void>
  removeItem: (productId: string) => Promise<void>
  clear: () => Promise<void>
}

function readGuestCart(): CartItem[] {
  if (typeof window === "undefined") return []
  return parseJsonField<CartItem[]>(window.localStorage.getItem(GUEST_CART_STORAGE_KEY), [])
}

function writeGuestCart(items: CartItem[]): void {
  if (typeof window === "undefined") return
  window.localStorage.setItem(GUEST_CART_STORAGE_KEY, stringifyJsonField(items))
}

/**
 * A "customer" application role, not an anonymous or unauthenticated session, is required to
 * persist a cart in the `carts` collection - Mudbase's ownership-conditioned permission only
 * grants create/read/update/delete to the `customer` customRole (see plan/build-plan.md). A
 * guest session (systemRole "viewer", customRole null) is denied. This hook keeps the cart in
 * localStorage until the shopper has a real customer account, then hands off to the server -
 * see migrateGuestCartToServer() in checkout, called right after registration succeeds.
 */
const GUEST_CART_QUERY_KEY = ["cart", "guest"] as const

export function useCart(): UseCartReturn {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()
  const userId = session?.user?.id
  const isCustomer = session?.user?.customRole === "customer"

  // A shared query-cache entry (not local useState) so every component that calls useCart() -
  // the header badge, the cart page, the checkout page - re-renders the moment any one of them
  // adds/updates/removes an item, instead of only reflecting whatever localStorage held when
  // that particular component happened to mount.
  const guestCartQuery = useQuery<CartItem[]>({
    queryKey: GUEST_CART_QUERY_KEY,
    queryFn: () => readGuestCart(),
    enabled: !isCustomer,
    initialData: () => (typeof window === "undefined" ? [] : undefined),
  })

  const cartQuery = useQuery<Cart | null>({
    queryKey: ["cart", userId],
    queryFn: async () => {
      const res = await client.getDocuments<Cart>(CARTS_COLLECTION_ID, { filter: { userId } })
      return res.data[0] ?? null
    },
    enabled: isCustomer && !!userId,
  })

  const items = useMemo(
    () => (isCustomer ? parseJsonField<CartItem[]>(cartQuery.data?.itemsJson, []) : (guestCartQuery.data ?? [])),
    [isCustomer, cartQuery.data, guestCartQuery.data],
  )

  const persist = useMutation({
    mutationFn: async (nextItems: CartItem[]) => {
      if (!isCustomer || !userId) {
        writeGuestCart(nextItems)
        return null
      }
      const itemsJson = stringifyJsonField(nextItems)
      // Re-fetch the authoritative cart right before deciding create-vs-update, rather than
      // trusting the React Query cache's cartQuery.data - that value can still be undefined
      // (query not yet resolved) in the exact window right after a guest becomes a customer
      // (registration flips isCustomer before the cart query has had a chance to load), which
      // previously caused a fresh, empty cart to be created on the very next add, discarding
      // whatever the migration had just written and making every subsequent add look like it
      // silently did nothing (the newly-created cart from that add was never read back either).
      const res = await client.getDocuments<Cart>(CARTS_COLLECTION_ID, { filter: { userId } })
      const existing = res.data[0] ?? null
      if (existing) {
        return client.updateDocument<Cart>(CARTS_COLLECTION_ID, existing._id, { itemsJson })
      }
      return client.createDocument<Cart>(CARTS_COLLECTION_ID, { userId, itemsJson })
    },
    onSuccess: (doc, nextItems) => {
      if (doc) {
        queryClient.setQueryData<Cart>(["cart", userId], doc)
      } else {
        queryClient.setQueryData<CartItem[]>(GUEST_CART_QUERY_KEY, nextItems)
      }
    },
  })

  const addItem = useCallback(
    async (item: Omit<CartItem, "quantity">, quantity = 1) => {
      const next = [...items]
      const existingIndex = next.findIndex((i) => i.productId === item.productId)
      if (existingIndex >= 0) {
        const current = next[existingIndex]
        if (current) next[existingIndex] = { ...current, quantity: current.quantity + quantity }
      } else {
        next.push({ ...item, quantity })
      }
      await persist.mutateAsync(next)
    },
    [items, persist],
  )

  const updateQuantity = useCallback(
    async (productId: string, quantity: number) => {
      const next =
        quantity <= 0
          ? items.filter((i) => i.productId !== productId)
          : items.map((i) => (i.productId === productId ? { ...i, quantity } : i))
      await persist.mutateAsync(next)
    },
    [items, persist],
  )

  const removeItem = useCallback(
    async (productId: string) => {
      await persist.mutateAsync(items.filter((i) => i.productId !== productId))
    },
    [items, persist],
  )

  const clear = useCallback(async () => {
    await persist.mutateAsync([])
  }, [persist])

  const subtotalCents = items.reduce((sum, i) => sum + i.priceCents * i.quantity, 0)

  return {
    items,
    subtotalCents,
    // isPending, not isLoading - the moment isCustomer flips true (right after sign-in at
    // checkout), cartQuery goes from disabled to enabled but TanStack Query v5's isLoading
    // (isPending && isFetching) can still read false for one render tick before the newly-
    // enabled query actually starts fetching, since isFetching lags a tick behind the enabled
    // flip. That gap let checkout's "cart is empty" branch fire before the real cart ever had a
    // chance to load - isPending stays true the whole time no data has resolved yet, regardless
    // of that isFetching lag.
    isLoading: isCustomer ? cartQuery.isPending : false,
    addItem,
    updateQuantity,
    removeItem,
    clear,
  }
}

/** Called once, right after a guest completes real customer registration OR signs in at checkout. */
export async function migrateGuestCartToServer(
  client: {
    getDocuments: <T>(c: string, q?: { filter?: Record<string, unknown> }) => Promise<{ data: T[] }>
    createDocument: <T>(c: string, d: Record<string, unknown>) => Promise<T>
    updateDocument: <T>(c: string, id: string, d: Record<string, unknown>) => Promise<T>
  },
  userId: string,
): Promise<void> {
  const guestItems = readGuestCart()
  if (guestItems.length === 0) return

  // A returning customer signing in (rather than registering fresh) may already have a server
  // cart from an earlier session - blindly creating a new cart document here would duplicate it
  // instead of merging, the same duplicate-cart risk already guarded against in useCart's own
  // persist mutation. Look up any existing cart first and merge quantities into it instead.
  const res = await client.getDocuments<Cart>(CARTS_COLLECTION_ID, { filter: { userId } })
  const existing = res.data[0] ?? null

  if (!existing) {
    await client.createDocument<Cart>(CARTS_COLLECTION_ID, { userId, itemsJson: stringifyJsonField(guestItems) })
    writeGuestCart([])
    return
  }

  const existingItems = parseJsonField<CartItem[]>(existing.itemsJson, [])
  const merged = [...existingItems]
  for (const guestItem of guestItems) {
    const idx = merged.findIndex((i) => i.productId === guestItem.productId)
    const current = idx >= 0 ? merged[idx] : undefined
    if (idx >= 0 && current) {
      merged[idx] = { ...current, quantity: current.quantity + guestItem.quantity }
    } else {
      merged.push(guestItem)
    }
  }
  await client.updateDocument<Cart>(CARTS_COLLECTION_ID, existing._id, { itemsJson: stringifyJsonField(merged) })
  writeGuestCart([])
}
