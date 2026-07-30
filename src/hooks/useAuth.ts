"use client"

import { useState, useCallback } from "react"
import { useRouter } from "next/navigation"
import { useMudbase } from "@/lib/mudbase-provider"
import { MudbaseError, type UserObject } from "@/lib/mudbase"
import { getMudbaseSocket } from "@/lib/mudbase-socket"

interface UseAuthReturn {
  user: UserObject | null
  loading: boolean
  error: string | null
  registerCustomer: (
    email: string,
    password: string,
    firstName: string,
    lastName: string,
    agreedToTerms: boolean,
  ) => Promise<boolean>
  login: (email: string, password: string, options?: { redirect?: boolean }) => Promise<boolean>
  logout: () => Promise<void>
  clearError: () => void
}

export function useAuth(): UseAuthReturn {
  const { client, session, loading: sessionLoading, refreshSession } = useMudbase()
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const registerCustomer = useCallback(
    async (
      email: string,
      password: string,
      firstName: string,
      lastName: string,
      agreedToTerms: boolean,
    ): Promise<boolean> => {
      setLoading(true)
      setError(null)
      try {
        await client.register({ email, password, firstName, lastName, role: "customer", agreedToTerms })
        await refreshSession()
        return true
      } catch (err) {
        setError(err instanceof MudbaseError ? err.message : "Registration failed")
        return false
      } finally {
        setLoading(false)
      }
    },
    [client, refreshSession],
  )

  const login = useCallback(
    async (email: string, password: string, options?: { redirect?: boolean }): Promise<boolean> => {
      setLoading(true)
      setError(null)
      try {
        const res = await client.login({ email, password })
        await refreshSession()
        // Checkout's "already have an account? sign in" path needs to stay on the checkout page
        // to finish the order, not bounce to home - callers there pass redirect: false.
        if (options?.redirect !== false) {
          router.push(res.user.customRole === "seller" ? "/seller" : "/")
        }
        return true
      } catch (err) {
        setError(err instanceof MudbaseError ? err.message : "Login failed")
        return false
      } finally {
        setLoading(false)
      }
    },
    [client, router, refreshSession],
  )

  const logout = useCallback(async () => {
    setLoading(true)
    try {
      await client.logout()
      // Without this, a socket connected while logged in stays connected authenticated as the
      // now-invalid session indefinitely - refreshSession() only ever calls connect() again on a
      // truthy token, never disconnects on a null one.
      getMudbaseSocket().disconnect()
      await refreshSession()
      router.push("/")
    } finally {
      setLoading(false)
    }
  }, [client, router, refreshSession])

  return {
    user: session?.user ?? null,
    loading: loading || sessionLoading,
    error,
    registerCustomer,
    login,
    logout,
    clearError: () => setError(null),
  }
}
