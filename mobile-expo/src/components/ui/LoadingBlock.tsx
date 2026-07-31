import { View } from "react-native";
import { cn } from "@/lib/cn";

export function LoadingBlock({ className }: { className?: string }): React.JSX.Element {
  return <View className={cn("animate-pulse rounded-lg bg-muted", className)} />;
}
