"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { useMudbase } from "@/lib/mudbase-provider"

export function SellerGuard({ children }: { children: React.ReactNode }): React.JSX.Element | null {
  const { session, loading } = useMudbase()
  const router = useRouter()
  const isSeller = session?.user?.customRole === "seller"

  useEffect(() => {
    if (!loading && !isSeller) {
      router.replace("/")
    }
  }, [loading, isSeller, router])

  if (loading || !isSeller) return null
  return <>{children}</>
}
