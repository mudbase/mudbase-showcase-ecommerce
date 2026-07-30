"use client"

import Link from "next/link"
import { SellerGuard } from "@/components/seller/SellerGuard"
import { SellerOrderQueue } from "@/components/seller/SellerOrderQueue"
import { ProductTable } from "@/components/seller/ProductTable"
import { Button } from "@/components/ui/button"

export default function SellerDashboardPage(): React.JSX.Element {
  return (
    <SellerGuard>
      <div className="container space-y-12 py-10">
        <section>
          <h1 className="mb-1 font-display text-2xl font-semibold tracking-tight">Orders</h1>
          <p className="mb-6 text-sm text-muted-foreground">Updates live over Mudbase realtime — no refresh needed.</p>
          <SellerOrderQueue />
        </section>

        <section>
          <div className="mb-6 flex items-center justify-between">
            <h2 className="font-display text-2xl font-semibold tracking-tight">Products</h2>
            <Button asChild>
              <Link href="/seller/products/new">Add product</Link>
            </Button>
          </div>
          <ProductTable />
        </section>
      </div>
    </SellerGuard>
  )
}
