import { Switch, Text, View } from "react-native";

export function LabeledSwitch({
  label,
  value,
  onValueChange,
}: {
  label: string;
  value: boolean;
  onValueChange: (next: boolean) => void;
}): React.JSX.Element {
  return (
    <View className="flex-row items-center justify-between py-1">
      <Text className="text-sm text-foreground">{label}</Text>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: "#e2dcd3", true: "#145c3f" }}
        accessibilityRole="switch"
        accessibilityLabel={label}
      />
    </View>
  );
}
