"use client"

import { useEffect } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { getMudbaseSocket } from "@/lib/mudbase-socket"
import { useMudbase } from "@/lib/mudbase-provider"
import type { Order } from "@/types/order"

interface RowEvent {
  projectId: string
  collectionId: string
  action: string
  data: Order
  timestamp: string
}

/**
 * Seller dashboard realtime feed: subscribes to the `orders` collection's Socket.IO room so new
 * orders and status changes appear the instant a customer checks out or an order updates,
 * without polling.
 */
export function useOrdersLive(ordersCollectionId: string, enabled: boolean): void {
  const { client } = useMudbase()
  const queryClient = useQueryClient()
  const projectId = client.getProjectId()

  useEffect(() => {
    if (!enabled) return
    const socket = getMudbaseSocket()

    const trySubscribe = (): void => {
      if (!socket.connected) return
      socket.emit("subscribe:collection", { projectId, collectionId: ordersCollectionId })
    }
    trySubscribe()
    const offStatus = socket.onStatus(trySubscribe)

    const upsert = (ev: RowEvent): void => {
      if (ev.collectionId !== ordersCollectionId) return
      queryClient.setQueryData(["collection", ordersCollectionId, "doc", ev.data._id], ev.data)
      queryClient.invalidateQueries({ queryKey: ["collection", ordersCollectionId] })
    }

    const offCreate = socket.on<RowEvent>("db:create", upsert)
    const offUpdate = socket.on<RowEvent>("db:update", upsert)

    return () => {
      socket.emit("unsubscribe:collection", { collectionId: ordersCollectionId })
      offStatus()
      offCreate()
      offUpdate()
    }
  }, [enabled, ordersCollectionId, projectId, queryClient])
}
