import { Text, View } from "react-native";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const badgeVariants = cva("self-start rounded-full border px-2.5 py-0.5", {
  variants: {
    variant: {
      default: "border-transparent bg-primary",
      secondary: "border-transparent bg-secondary",
      destructive: "border-transparent bg-destructive",
      success: "border-transparent bg-success",
      warning: "border-transparent bg-warning",
    },
  },
  defaultVariants: { variant: "default" },
});

const textVariants = cva("text-xs font-semibold", {
  variants: {
    variant: {
      default: "text-primary-foreground",
      secondary: "text-foreground",
      destructive: "text-destructive-foreground",
      success: "text-white",
      warning: "text-white",
    },
  },
  defaultVariants: { variant: "default" },
});

export interface BadgeProps extends VariantProps<typeof badgeVariants> {
  children: string;
  className?: string;
}

export function Badge({ children, variant, className }: BadgeProps): React.JSX.Element {
  return (
    <View className={cn(badgeVariants({ variant }), className)}>
      <Text className={textVariants({ variant })}>{children}</Text>
    </View>
  );
}
