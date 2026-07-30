"use client"

import { useEffect, useState, useCallback } from "react"
import { MUDBASE_URL } from "@/lib/config"
import type { PublicPaymentLink } from "@/lib/mudbase-server"

interface UsePaymentLinkStatusReturn {
  link: PublicPaymentLink | null
  loading: boolean
  error: string | null
}

/** Public, unauthenticated read — polls until the link reaches a terminal status. */
export function usePaymentLinkStatus(token: string, intervalMs = 4000): UsePaymentLinkStatusReturn {
  const [link, setLink] = useState<PublicPaymentLink | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchOnce = useCallback(async (): Promise<PublicPaymentLink | null> => {
    const res = await fetch(`${MUDBASE_URL}/api/payment-links/${token}`)
    if (!res.ok) {
      const body = (await res.json().catch(() => ({}))) as { error?: string }
      throw new Error(body.error ?? "Payment link not available")
    }
    const body = (await res.json()) as { link: PublicPaymentLink }
    return body.link
  }, [token])

  useEffect(() => {
    let cancelled = false
    let timer: ReturnType<typeof setTimeout> | null = null

    const tick = async (): Promise<void> => {
      try {
        const result = await fetchOnce()
        if (cancelled) return
        setLink(result)
        setError(null)
        setLoading(false)
        if (result && (result.status === "pending")) {
          timer = setTimeout(() => void tick(), intervalMs)
        }
      } catch (err) {
        if (cancelled) return
        setError(err instanceof Error ? err.message : "Couldn't check payment status")
        setLoading(false)
        timer = setTimeout(() => void tick(), intervalMs)
      }
    }

    void tick()
    return () => {
      cancelled = true
      if (timer) clearTimeout(timer)
    }
  }, [fetchOnce, intervalMs])

  return { link, loading, error }
}
