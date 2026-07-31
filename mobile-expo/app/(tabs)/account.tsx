import { Text, View } from "react-native";
import { router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { LogOut, Store } from "lucide-react-native";
import { useAuth } from "@/hooks/useAuth";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";

export default function AccountScreen(): React.JSX.Element {
  const { user, isSeller, logout, isSubmitting } = useAuth();

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <View className="gap-6 p-4">
        <Text className="font-semibold text-2xl text-foreground">Account</Text>

        <Card className="gap-2">
          <Text className="font-medium text-foreground">
            {user?.firstName} {user?.lastName}
          </Text>
          <Text className="text-sm text-muted-foreground">{user?.email}</Text>
          <Badge variant="secondary">{isSeller ? "Seller" : "Customer"}</Badge>
        </Card>

        {isSeller && (
          <Button
            variant="outline"
            icon={<Store size={16} color="#211d1a" />}
            onPress={() => router.push("/seller")}
          >
            Seller dashboard
          </Button>
        )}

        <Button
          variant="destructive"
          icon={<LogOut size={16} color="#fbf8f3" />}
          isLoading={isSubmitting}
          onPress={() => void logout()}
        >
          Sign out
        </Button>
      </View>
    </SafeAreaView>
  );
}
