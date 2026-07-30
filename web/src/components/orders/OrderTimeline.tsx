import { Check } from "lucide-react"
import { cn } from "@/lib/utils"
import type { OrderStatus } from "@/types/order"

const STEPS: { status: OrderStatus; label: string }[] = [
  { status: "pending", label: "Placed" },
  { status: "paid", label: "Paid" },
  { status: "shipped", label: "Shipped" },
  { status: "delivered", label: "Delivered" },
]

export function OrderTimeline({ status }: { status: OrderStatus }): React.JSX.Element {
  if (status === "cancelled") {
    return <p className="text-sm text-destructive">This order was cancelled.</p>
  }

  const effectiveStatus = status === "awaiting_payment" ? "pending" : status
  const currentIndex = STEPS.findIndex((s) => s.status === effectiveStatus)

  return (
    <ol className="flex items-center gap-2">
      {STEPS.map((step, i) => {
        const done = i <= currentIndex
        return (
          <li key={step.status} className="flex flex-1 items-center gap-2">
            <div
              className={cn(
                "flex h-7 w-7 shrink-0 items-center justify-center rounded-full border text-xs",
                done ? "border-primary bg-primary text-primary-foreground" : "border-border text-muted-foreground",
              )}
            >
              {done ? <Check className="h-3.5 w-3.5" /> : i + 1}
            </div>
            <span className={cn("text-sm", done ? "font-medium" : "text-muted-foreground")}>{step.label}</span>
            {i < STEPS.length - 1 && <div className={cn("h-px flex-1", done ? "bg-primary" : "bg-border")} />}
          </li>
        )
      })}
    </ol>
  )
}
