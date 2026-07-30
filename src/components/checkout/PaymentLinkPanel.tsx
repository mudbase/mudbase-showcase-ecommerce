"use client"

import { CheckCircle2, Clock, XCircle } from "lucide-react"
import { usePaymentLinkStatus } from "@/hooks/usePaymentLinkStatus"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

export function PaymentLinkPanel({ token }: { token: string }): React.JSX.Element {
  const { link, loading, error } = usePaymentLinkStatus(token)

  if (loading) {
    return <div className="h-64 animate-pulse rounded-lg bg-muted" />
  }

  if (error && !link) {
    return <p className="text-sm text-destructive">{error}</p>
  }

  if (!link) return <p className="text-sm text-muted-foreground">Payment link not found.</p>

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <span>Complete your payment</span>
          <StatusBadge status={link.status} />
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {link.status === "paid" ? (
          <div className="flex items-center gap-2 text-emerald-600">
            <CheckCircle2 className="h-5 w-5" />
            <span>Payment received — thank you!</span>
          </div>
        ) : link.status === "expired" || link.status === "cancelled" ? (
          <div className="flex items-center gap-2 text-destructive">
            <XCircle className="h-5 w-5" />
            <span>This payment link is no longer active.</span>
          </div>
        ) : (
          <>
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Clock className="h-4 w-4 animate-pulse" />
              Waiting for payment — this page updates automatically.
            </div>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Amount</dt>
                <dd className="tabular-nums">
                  {link.amount} {link.currency}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Network</dt>
                <dd>{link.network}</dd>
              </div>
              <div className="flex justify-between gap-4">
                <dt className="shrink-0 text-muted-foreground">Send to</dt>
                <dd className="break-all text-right font-mono text-xs">{link.address}</dd>
              </div>
            </dl>
          </>
        )}
      </CardContent>
    </Card>
  )
}

function StatusBadge({ status }: { status: string }): React.JSX.Element {
  if (status === "paid") return <Badge variant="success">Paid</Badge>
  if (status === "expired" || status === "cancelled") return <Badge variant="destructive">{status}</Badge>
  return <Badge variant="warning">Pending</Badge>
}
