import { useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { Link } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { RegisterForm } from "@/components/auth/RegisterForm";
import type { RegisterOutcome } from "@/api/client";

export default function RegisterScreen(): React.JSX.Element {
  const [verificationMessage, setVerificationMessage] = useState<string | null>(null);

  const handleOutcome = (outcome: RegisterOutcome): void => {
    // "authenticated" needs no action here — the root layout's AuthGuard
    // redirects away from (auth) the instant `user` becomes non-null.
    if (outcome.status === "verification_required") {
      setVerificationMessage(outcome.message);
    }
  };

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top", "bottom"]}>
      <ScrollView contentContainerClassName="flex-grow justify-center px-6 py-10" keyboardShouldPersistTaps="handled">
        <View className="mb-8 gap-1">
          <Text className="font-semibold text-3xl text-foreground">Create your account</Text>
          <Text className="text-muted-foreground">Your cart and orders will be tied to this account.</Text>
        </View>
        {verificationMessage ? (
          <View className="gap-4">
            <Text className="text-foreground">{verificationMessage}</Text>
            <Link href="/(auth)/login" className="text-sm font-medium text-primary underline">
              Go to sign in
            </Link>
          </View>
        ) : (
          <>
            <RegisterForm onSuccess={handleOutcome} />
            <View className="mt-6 flex-row justify-center gap-1">
              <Text className="text-sm text-muted-foreground">Already have an account?</Text>
              <Link href="/(auth)/login" className="text-sm font-medium text-primary underline">
                Sign in
              </Link>
            </View>
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
