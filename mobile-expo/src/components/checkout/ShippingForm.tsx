import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { View } from "react-native";
import { shippingAddressSchema, type ShippingAddress } from "@/api/schemas";
import { TextField } from "@/components/ui/TextField";
import { Button } from "@/components/ui/Button";

interface ShippingFormProps {
  onSubmit: (address: ShippingAddress) => Promise<void>;
  submitting: boolean;
}

export function ShippingForm({ onSubmit, submitting }: ShippingFormProps): React.JSX.Element {
  const {
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<ShippingAddress>({
    resolver: zodResolver(shippingAddressSchema),
    defaultValues: { fullName: "", line1: "", line2: "", city: "", region: "", postalCode: "", country: "" },
  });

  return (
    <View className="gap-4">
      <Controller
        control={control}
        name="fullName"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField label="Full name" value={value} onChangeText={onChange} onBlur={onBlur} autoComplete="name" error={errors.fullName?.message} />
        )}
      />
      <Controller
        control={control}
        name="line1"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField label="Address" value={value} onChangeText={onChange} onBlur={onBlur} autoComplete="street-address" error={errors.line1?.message} />
        )}
      />
      <Controller
        control={control}
        name="line2"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField label="Apartment, suite, etc. (optional)" value={value} onChangeText={onChange} onBlur={onBlur} />
        )}
      />
      <View className="flex-row gap-3">
        <Controller
          control={control}
          name="city"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField label="City" value={value} onChangeText={onChange} onBlur={onBlur} containerClassName="flex-1" error={errors.city?.message} />
          )}
        />
        <Controller
          control={control}
          name="region"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField label="State / region" value={value} onChangeText={onChange} onBlur={onBlur} containerClassName="flex-1" error={errors.region?.message} />
          )}
        />
      </View>
      <View className="flex-row gap-3">
        <Controller
          control={control}
          name="postalCode"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField label="Postal code" value={value} onChangeText={onChange} onBlur={onBlur} containerClassName="flex-1" error={errors.postalCode?.message} />
          )}
        />
        <Controller
          control={control}
          name="country"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField label="Country" value={value} onChangeText={onChange} onBlur={onBlur} containerClassName="flex-1" error={errors.country?.message} />
          )}
        />
      </View>
      <Button onPress={handleSubmit((values) => onSubmit(values))} isLoading={submitting} className="mt-2">
        {submitting ? "Placing order…" : "Continue to payment"}
      </Button>
    </View>
  );
}
