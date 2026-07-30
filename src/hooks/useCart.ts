"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { parseJsonField, stringifyJsonField } from "@/lib/json-field"
import type { Cart, CartItem } from "@/types/cart"

const CARTS_COLLECTION = "carts"
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
export function useCart(): UseCartReturn {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()
  const userId = session?.user?.id
  const isCustomer = session?.user?.customRole === "customer"

  const [guestItems, setGuestItems] = useState<CartItem[]>([])
  useEffect(() => {
    setGuestItems(readGuestCart())
  }, [])

  const cartQuery = useQuery<Cart | null>({
    queryKey: ["cart", userId],
    queryFn: async () => {
      const res = await client.getDocuments<Cart>(CARTS_COLLECTION, { filter: { userId } })
      return res.data[0] ?? null
    },
    enabled: isCustomer && !!userId,
  })

  const items = useMemo(
    () => (isCustomer ? parseJsonField<CartItem[]>(cartQuery.data?.itemsJson, []) : guestItems),
    [isCustomer, cartQuery.data, guestItems],
  )

  const persist = useMutation({
    mutationFn: async (nextItems: CartItem[]) => {
      if (!isCustomer || !userId) {
        writeGuestCart(nextItems)
        setGuestItems(nextItems)
        return null
      }
      const existing = cartQuery.data
      const itemsJson = stringifyJsonField(nextItems)
      if (existing) {
        return client.updateDocument<Cart>(CARTS_COLLECTION, existing._id, { itemsJson })
      }
      return client.createDocument<Cart>(CARTS_COLLECTION, { userId, itemsJson })
    },
    onSuccess: (doc) => {
      if (doc) queryClient.setQueryData<Cart>(["cart", userId], doc)
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
    isLoading: isCustomer ? cartQuery.isLoading : false,
    addItem,
    updateQuantity,
    removeItem,
    clear,
  }
}

/** Called once, right after a guest completes real customer registration at checkout. */
export async function migrateGuestCartToServer(
  client: { createDocument: <T>(c: string, d: Record<string, unknown>) => Promise<T> },
  userId: string,
): Promise<void> {
  const guestItems = readGuestCart()
  if (guestItems.length === 0) return
  await client.createDocument<Cart>(CARTS_COLLECTION, { userId, itemsJson: stringifyJsonField(guestItems) })
  writeGuestCart([])
}
