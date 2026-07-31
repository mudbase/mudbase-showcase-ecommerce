import { Pressable, ScrollView, Text } from "react-native";
import { cn } from "@/lib/cn";

interface CategoryFilterProps {
  categories: string[];
  value: string | null;
  onChange: (category: string | null) => void;
}

export function CategoryFilter({ categories, value, onChange }: CategoryFilterProps): React.JSX.Element {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      className="flex-row"
      contentContainerClassName="gap-2 px-4"
      accessibilityRole="tablist"
    >
      <Pressable
        onPress={() => onChange(null)}
        accessibilityRole="tab"
        accessibilityState={{ selected: value === null }}
        className={cn(
          "rounded-full border px-3 py-1.5",
          value === null ? "border-primary bg-primary" : "border-border bg-card",
        )}
      >
        <Text className={value === null ? "text-sm text-primary-foreground" : "text-sm text-foreground"}>All</Text>
      </Pressable>
      {categories.map((category) => (
        <Pressable
          key={category}
          onPress={() => onChange(category)}
          accessibilityRole="tab"
          accessibilityState={{ selected: value === category }}
          className={cn(
            "rounded-full border px-3 py-1.5",
            value === category ? "border-primary bg-primary" : "border-border bg-card",
          )}
        >
          <Text className={value === category ? "text-sm text-primary-foreground" : "text-sm text-foreground"}>
            {category}
          </Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}
