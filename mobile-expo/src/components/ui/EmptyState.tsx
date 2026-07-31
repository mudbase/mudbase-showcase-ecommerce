import { Text, View } from "react-native";

export function EmptyState({ message }: { message: string }): React.JSX.Element {
  return (
    <View className="items-center rounded-lg border border-dashed border-border py-16">
      <Text className="px-6 text-center text-muted-foreground">{message}</Text>
    </View>
  );
}
