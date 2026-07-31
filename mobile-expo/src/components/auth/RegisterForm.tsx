import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Pressable, Text, View } from "react-native";
import { z } from "zod";
import { useAuth } from "@/hooks/useAuth";
import { TextField } from "@/components/ui/TextField";
import { Button } from "@/components/ui/Button";
import { ErrorNotice } from "@/components/ui/ErrorNotice";
import type { RegisterOutcome } from "@/api/client";

const registerSchema = z.object({
  firstName: z.string().min(1, "First name is required"),
  lastName: z.string().min(1, "Last name is required"),
  email: z.email("Enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  agreedToTerms: z.boolean().refine((v) => v === true, {
    message: "You must agree to the Terms of Service and Privacy Policy.",
  }),
});

type RegisterFormValues = z.infer<typeof registerSchema>;

export function RegisterForm({ onSuccess }: { onSuccess: (outcome: RegisterOutcome) => void }): React.JSX.Element {
  const { registerCustomer, isSubmitting, error, clearError } = useAuth();
  const {
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<RegisterFormValues>({
    resolver: zodResolver(registerSchema),
    defaultValues: { firstName: "", lastName: "", email: "", password: "", agreedToTerms: false },
  });

  const onSubmit = async (values: RegisterFormValues): Promise<void> => {
    clearError();
    const outcome = await registerCustomer(values);
    if (outcome) onSuccess(outcome);
  };

  return (
    <View className="gap-4">
      {error && <ErrorNotice message={error} />}
      <View className="flex-row gap-3">
        <Controller
          control={control}
          name="firstName"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="First name"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              autoComplete="given-name"
              containerClassName="flex-1"
              error={errors.firstName?.message}
            />
          )}
        />
        <Controller
          control={control}
          name="lastName"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Last name"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              autoComplete="family-name"
              containerClassName="flex-1"
              error={errors.lastName?.message}
            />
          )}
        />
      </View>
      <Controller
        control={control}
        name="email"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Email"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
            error={errors.email?.message}
          />
        )}
      />
      <Controller
        control={control}
        name="password"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Password"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            secureTextEntry
            autoComplete="new-password"
            error={errors.password?.message}
          />
        )}
      />
      <Controller
        control={control}
        name="agreedToTerms"
        render={({ field: { onChange, value } }) => (
          <View className="gap-1">
            <Pressable
              onPress={() => onChange(!value)}
              accessibilityRole="checkbox"
              accessibilityState={{ checked: value }}
              className="flex-row items-start gap-2"
            >
              <View className={`mt-0.5 h-4 w-4 items-center justify-center rounded border ${value ? "border-primary bg-primary" : "border-border"}`}>
                {value && <Text className="text-[10px] leading-none text-primary-foreground">✓</Text>}
              </View>
              <Text className="flex-1 text-sm text-foreground">I agree to the Terms of Service and Privacy Policy.</Text>
            </Pressable>
            {errors.agreedToTerms && <Text className="text-xs text-destructive">{errors.agreedToTerms.message}</Text>}
          </View>
        )}
      />
      <Button onPress={handleSubmit(onSubmit)} isLoading={isSubmitting}>
        {isSubmitting ? "Creating account…" : "Create account"}
      </Button>
    </View>
  );
}
