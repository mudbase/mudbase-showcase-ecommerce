import { Text, View } from "react-native";
import { CheckCircle2, Clock, XCircle } from "lucide-react-native";
import { usePaymentLinkStatus } from "@/hooks/usePaymentLinkStatus";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { LoadingBlock } from "@/components/ui/LoadingBlock";
import type { PaymentLinkStatus } from "@/api/schemas";

export function PaymentLinkPanel({ token }: { token: string }): React.JSX.Element {
  const { link, loading, error } = usePaymentLinkStatus(token);

  if (loading) {
    return <LoadingBlock className="h-64" />;
  }

  if (error && !link) {
    return <Text className="text-sm text-destructive">{error}</Text>;
  }

  if (!link) {
    return <Text className="text-sm text-muted-foreground">Payment link not found.</Text>;
  }

  return (
    <Card className="gap-4">
      <View className="flex-row items-center justify-between">
        <Text className="font-medium text-foreground">Complete your payment</Text>
        <StatusBadge status={link.status} />
      </View>

      {link.status === "paid" ? (
        <View className="flex-row items-center gap-2">
          <CheckCircle2 size={20} color="#16794f" />
          <Text className="text-success">Payment received — thank you!</Text>
        </View>
      ) : link.status === "expired" || link.status === "cancelled" ? (
        <View className="flex-row items-center gap-2">
          <XCircle size={20} color="#c53021" />
          <Text className="text-destructive">This payment link is no longer active.</Text>
        </View>
      ) : (
        <>
          <View className="flex-row items-center gap-2">
            <Clock size={16} color="#6b615a" />
            <Text className="text-sm text-muted-foreground">Waiting for payment — this screen updates automatically.</Text>
          </View>
          <View className="gap-2">
            <View className="flex-row justify-between">
              <Text className="text-sm text-muted-foreground">Amount</Text>
              <Text className="text-sm tabular-nums text-foreground">
                {link.amount} {link.currency}
              </Text>
            </View>
            <View className="flex-row justify-between">
              <Text className="text-sm text-muted-foreground">Network</Text>
              <Text className="text-sm text-foreground">{link.network}</Text>
            </View>
            <View className="flex-row justify-between gap-4">
              <Text className="shrink-0 text-sm text-muted-foreground">Send to</Text>
              <Text selectable className="flex-1 text-right font-mono text-xs text-foreground">
                {link.address}
              </Text>
            </View>
          </View>
        </>
      )}
    </Card>
  );
}

function StatusBadge({ status }: { status: PaymentLinkStatus }): React.JSX.Element {
  if (status === "paid") return <Badge variant="success">Paid</Badge>;
  if (status === "expired" || status === "cancelled") return <Badge variant="destructive">{status}</Badge>;
  return <Badge variant="warning">Pending</Badge>;
}
