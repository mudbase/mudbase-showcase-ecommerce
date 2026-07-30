"use client"

import { use } from "react"
import { PaymentLinkPanel } from "@/components/checkout/PaymentLinkPanel"

export default function PaymentPage({ params }: { params: Promise<{ token: string }> }): React.JSX.Element {
  const { token } = use(params)

  return (
    <div className="container flex justify-center py-16">
      <div className="w-full max-w-md space-y-6">
        <h1 className="text-center font-display text-2xl font-semibold tracking-tight">Pay for your order</h1>
        <PaymentLinkPanel token={token} />
      </div>
    </div>
  )
}
