"use client"

import Link from "next/link"
import { ShoppingBag, Store, LogOut, PackageSearch } from "lucide-react"
import { useMudbase } from "@/lib/mudbase-provider"
import { useAuth } from "@/hooks/useAuth"
import { useCart } from "@/hooks/useCart"
import { Button } from "@/components/ui/button"

export function Header(): React.JSX.Element {
  const { session } = useMudbase()
  const { logout } = useAuth()
  const { items } = useCart()
  const isSignedIn = !!session?.user && session.user.isAnonymous !== true
  const isSeller = session?.user?.customRole === "seller"
  const itemCount = items.reduce((sum, i) => sum + i.quantity, 0)

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-background/95 backdrop-blur">
      <div className="container flex h-16 items-center justify-between">
        <Link href="/" className="font-display text-xl font-semibold tracking-tight">
          Commonwealth Goods
        </Link>

        <nav className="flex items-center gap-2">
          {isSeller && (
            <Button asChild variant="ghost" size="sm">
              <Link href="/seller">
                <Store className="mr-2 h-4 w-4" />
                Seller dashboard
              </Link>
            </Button>
          )}

          {isSignedIn && (
            <Button asChild variant="ghost" size="sm">
              <Link href="/orders">
                <PackageSearch className="mr-2 h-4 w-4" />
                Orders
              </Link>
            </Button>
          )}

          <Button asChild variant="ghost" size="icon" className="relative">
            <Link href="/cart" aria-label={`Cart, ${itemCount} item${itemCount === 1 ? "" : "s"}`}>
              <ShoppingBag className="h-5 w-5" />
              {itemCount > 0 && (
                <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent px-1 text-[10px] font-semibold text-accent-foreground">
                  {itemCount}
                </span>
              )}
            </Link>
          </Button>

          {isSignedIn ? (
            <Button variant="outline" size="sm" onClick={() => void logout()}>
              <LogOut className="mr-2 h-4 w-4" />
              Sign out
            </Button>
          ) : (
            <Button asChild size="sm">
              <Link href="/login">Sign in</Link>
            </Button>
          )}
        </nav>
      </div>
    </header>
  )
}
