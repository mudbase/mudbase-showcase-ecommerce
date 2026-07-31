import { useState } from "react";
import { Pressable, Text, View } from "react-native";
import { Minus, Plus, ShoppingBag } from "lucide-react-native";
import { useCart } from "@/hooks/useCart";
import { Button } from "@/components/ui/Button";
import type { Product } from "@/api/schemas";

type Status = "idle" | "adding" | "added" | "error";

export function AddToCartForm({ product }: { product: Product }): React.JSX.Element {
  const { addItem, requiresCustomerAccount } = useCart();
  const [quantity, setQuantity] = useState(1);
  const [status, setStatus] = useState<Status>("idle");
  const outOfStock = product.stock <= 0;

  const handleAdd = async (): Promise<void> => {
    setStatus("adding");
    try {
      await addItem(
        {
          productId: product._id,
          name: product.name,
          priceCents: product.priceCents,
          currency: product.currency,
          imageUrl: product.imageUrl,
        },
        quantity,
      );
      setStatus("added");
      setTimeout(() => setStatus("idle"), 1500);
    } catch {
      setStatus("error");
      setTimeout(() => setStatus("idle"), 2500);
    }
  };

  if (requiresCustomerAccount) {
    return (
      <View className="rounded-md border border-border bg-secondary p-3">
        <Text className="text-sm text-muted-foreground">Sign in with a customer account to add this to your cart.</Text>
      </View>
    );
  }

  const label = outOfStock ? "Out of stock" : status === "added" ? "Added to cart" : status === "error" ? "Couldn't add — try again" : "Add to cart";

  return (
    <View className="gap-2">
      <View className="flex-row items-center gap-3">
        <View className="flex-row items-center rounded-md border border-border">
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Decrease quantity"
            hitSlop={8}
            onPress={() => setQuantity((q) => Math.max(1, q - 1))}
            className="h-10 w-10 items-center justify-center active:bg-secondary"
          >
            <Minus size={16} color="#211d1a" />
          </Pressable>
          <Text className="w-8 text-center tabular-nums text-foreground">{quantity}</Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Increase quantity"
            hitSlop={8}
            onPress={() => setQuantity((q) => Math.min(product.stock || 1, q + 1))}
            className="h-10 w-10 items-center justify-center active:bg-secondary"
          >
            <Plus size={16} color="#211d1a" />
          </Pressable>
        </View>
        <Button
          onPress={() => void handleAdd()}
          disabled={outOfStock || status === "adding"}
          isLoading={status === "adding"}
          icon={<ShoppingBag size={16} color="#fbf8f3" />}
          className="flex-1"
        >
          {label}
        </Button>
      </View>
      {status === "error" && (
        <Text accessibilityRole="alert" className="text-xs text-destructive">
          Something went wrong adding this to your cart. Please try again.
        </Text>
      )}
    </View>
  );
}
