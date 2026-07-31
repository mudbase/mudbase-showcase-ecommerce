import { Text, View } from "react-native";
import { Check } from "lucide-react-native";
import { cn } from "@/lib/cn";
import type { OrderStatus } from "@/api/schemas";

const STEPS: { status: OrderStatus; label: string }[] = [
  { status: "pending", label: "Placed" },
  { status: "paid", label: "Paid" },
  { status: "shipped", label: "Shipped" },
  { status: "delivered", label: "Delivered" },
];

export function OrderTimeline({ status }: { status: OrderStatus }): React.JSX.Element {
  if (status === "cancelled") {
    return <Text className="text-sm text-destructive">This order was cancelled.</Text>;
  }

  const effectiveStatus = status === "awaiting_payment" ? "pending" : status;
  const currentIndex = STEPS.findIndex((s) => s.status === effectiveStatus);

  return (
    <View className="flex-row items-center">
      {STEPS.map((step, i) => {
        const done = i <= currentIndex;
        return (
          <View key={step.status} className="flex-1 flex-row items-center gap-2">
            <View
              className={cn(
                "h-7 w-7 shrink-0 items-center justify-center rounded-full border",
                done ? "border-primary bg-primary" : "border-border",
              )}
            >
              {done ? <Check size={14} color="#fbf8f3" /> : <Text className="text-xs text-muted-foreground">{i + 1}</Text>}
            </View>
            <Text className={cn("text-xs", done ? "font-medium text-foreground" : "text-muted-foreground")}>{step.label}</Text>
            {i < STEPS.length - 1 && <View className={cn("h-px flex-1", done ? "bg-primary" : "bg-border")} />}
          </View>
        );
      })}
    </View>
  );
}
