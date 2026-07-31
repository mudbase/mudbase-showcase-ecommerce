import { ScrollView, Text, View } from "react-native";
import { Link } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { LoginForm } from "@/components/auth/LoginForm";

export default function LoginScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top", "bottom"]}>
      <ScrollView contentContainerClassName="flex-grow justify-center px-6 py-10" keyboardShouldPersistTaps="handled">
        <View className="mb-8 gap-1">
          <Text className="font-semibold text-3xl text-foreground">Commonwealth Goods</Text>
          <Text className="text-muted-foreground">Sign in to browse the catalog and manage your orders.</Text>
        </View>
        {/* No manual navigation needed on success — the root layout's AuthGuard
            redirects away from (auth) the instant `user` becomes non-null. */}
        <LoginForm onSuccess={() => undefined} />
        <View className="mt-6 flex-row justify-center gap-1">
          <Text className="text-sm text-muted-foreground">New here?</Text>
          <Link href="/(auth)/register" className="text-sm font-medium text-primary underline">
            Create an account
          </Link>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
