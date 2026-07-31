import { Controller, useFieldArray, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Pressable, Text, View } from "react-native";
import { Plus, X } from "lucide-react-native";
import { z } from "zod";
import { TextField } from "@/components/ui/TextField";
import { LabeledSwitch } from "@/components/ui/LabeledSwitch";
import { Button } from "@/components/ui/Button";

const MAX_GALLERY_PHOTOS = 8;
const NON_NEGATIVE_INT = /^\d+$/;

/**
 * Every numeric field is validated (and typed) as a string, not coerced to a
 * number inside the schema — RN's TextInput only ever emits strings via
 * onChangeText, and mixing z.coerce.number() into the same generic RHF uses
 * for both the Controller's `value`/`onChange` types AND the validated submit
 * type produces a real type mismatch (TextInput hands onChange a string; the
 * coerced field type is `number`). Callers convert to numbers via
 * toProductPayload() right before hitting the API, matching the DB's actual
 * numeric fields.
 */
const productFormSchema = z
  .object({
    name: z.string().min(1, "Name is required"),
    description: z.string().optional(),
    priceCents: z.string().regex(NON_NEGATIVE_INT, "Enter a whole number of cents"),
    compareAtPriceCents: z
      .string()
      .optional()
      .refine((v) => v === undefined || v === "" || NON_NEGATIVE_INT.test(v), "Enter a whole number of cents"),
    currency: z.string().min(1),
    imageUrl: z.union([z.url("Enter a valid image URL"), z.literal("")]),
    galleryUrls: z
      .array(z.object({ url: z.url("Enter a valid image URL") }))
      .max(MAX_GALLERY_PHOTOS, `Up to ${MAX_GALLERY_PHOTOS} extra photos`),
    category: z.string().optional(),
    stock: z.string().regex(NON_NEGATIVE_INT, "Enter a whole non-negative number"),
    isActive: z.boolean(),
  })
  .refine((data) => !data.compareAtPriceCents || Number(data.compareAtPriceCents) > Number(data.priceCents), {
    message: "Compare-at price must be higher than the current price",
    path: ["compareAtPriceCents"],
  });

export type ProductFormValues = z.infer<typeof productFormSchema>;

// A `type` alias (not `interface`) — plain object type aliases are assignable
// to `Record<string, unknown>` (what useCreateDocument/useUpdateDocument
// expect), while `interface` declarations are not, even with identical shape;
// TypeScript only infers an implicit index signature for the former.
export type ProductPayload = {
  name: string;
  description: string | undefined;
  priceCents: number;
  compareAtPriceCents: number | undefined;
  currency: string;
  imageUrl: string | undefined;
  galleryJson: string;
  category: string | undefined;
  stock: number;
  isActive: boolean;
};

/** Converts validated string form fields into the numeric shape the `products` collection stores. */
export function toProductPayload(values: ProductFormValues): ProductPayload {
  return {
    name: values.name,
    description: values.description || undefined,
    priceCents: Number(values.priceCents),
    compareAtPriceCents: values.compareAtPriceCents ? Number(values.compareAtPriceCents) : undefined,
    currency: values.currency,
    imageUrl: values.imageUrl || undefined,
    galleryJson: JSON.stringify(values.galleryUrls.map((g) => g.url)),
    category: values.category || undefined,
    stock: Number(values.stock),
    isActive: values.isActive,
  };
}

interface ProductFormProps {
  initialValues?: Partial<ProductFormValues>;
  onSave: (values: ProductFormValues) => Promise<void>;
  submitLabel?: string;
}

export function ProductForm({ initialValues, onSave, submitLabel = "Save product" }: ProductFormProps): React.JSX.Element {
  const {
    control,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ProductFormValues>({
    resolver: zodResolver(productFormSchema),
    defaultValues: {
      currency: "USD",
      isActive: true,
      priceCents: "0",
      stock: "0",
      imageUrl: "",
      galleryUrls: [],
      name: "",
      description: "",
      category: "",
      ...initialValues,
    },
  });

  const { fields, append, remove } = useFieldArray({ control, name: "galleryUrls" });

  return (
    <View className="gap-4">
      <Controller
        control={control}
        name="name"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField label="Name" value={value} onChangeText={onChange} onBlur={onBlur} error={errors.name?.message} />
        )}
      />
      <Controller
        control={control}
        name="description"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Description"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            multiline
            numberOfLines={4}
            className="min-h-24"
            textAlignVertical="top"
          />
        )}
      />
      <View className="flex-row gap-3">
        <Controller
          control={control}
          name="priceCents"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Price (cents)"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              keyboardType="numeric"
              containerClassName="flex-1"
              error={errors.priceCents?.message}
            />
          )}
        />
        <Controller
          control={control}
          name="stock"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Stock"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              keyboardType="numeric"
              containerClassName="flex-1"
              error={errors.stock?.message}
            />
          )}
        />
      </View>
      <Controller
        control={control}
        name="compareAtPriceCents"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Compare-at price (cents)"
            value={value ?? ""}
            onChangeText={onChange}
            onBlur={onBlur}
            keyboardType="numeric"
            placeholder="Leave blank for no discount"
            error={errors.compareAtPriceCents?.message}
          />
        )}
      />
      <Controller
        control={control}
        name="category"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField label="Category" value={value} onChangeText={onChange} onBlur={onBlur} />
        )}
      />
      <View className="gap-1.5">
        <Controller
          control={control}
          name="imageUrl"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Main image URL"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              placeholder="https://…"
              autoCapitalize="none"
              error={errors.imageUrl?.message}
            />
          )}
        />
        <Text className="text-xs text-muted-foreground">
          Mudbase file uploads require an owner/admin/developer role, which project end-users (sellers included)
          don&apos;t have — see README &quot;Known limitations&quot;. Paste a hosted image URL for now.
        </Text>
      </View>

      <View className="gap-2">
        <Text className="text-sm font-medium text-foreground">Additional photos</Text>
        {fields.map((field, index) => (
          <View key={field.id} className="flex-row items-start gap-2">
            <Controller
              control={control}
              name={`galleryUrls.${index}.url` as const}
              render={({ field: { onChange, onBlur, value } }) => (
                <TextField
                  label=""
                  value={value}
                  onChangeText={onChange}
                  onBlur={onBlur}
                  placeholder="https://…"
                  autoCapitalize="none"
                  containerClassName="flex-1"
                  error={errors.galleryUrls?.[index]?.url?.message}
                />
              )}
            />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Remove photo"
              onPress={() => remove(index)}
              className="mt-1 h-10 w-10 items-center justify-center rounded-md active:bg-secondary"
            >
              <X size={16} color="#211d1a" />
            </Pressable>
          </View>
        ))}
        {fields.length < MAX_GALLERY_PHOTOS && (
          <Button variant="outline" size="sm" icon={<Plus size={14} color="#211d1a" />} onPress={() => append({ url: "" })}>
            Add photo
          </Button>
        )}
        <Text className="text-xs text-muted-foreground">Shown as a swipeable gallery on the product detail screen.</Text>
      </View>

      <Controller
        control={control}
        name="isActive"
        render={({ field: { onChange, value } }) => (
          <LabeledSwitch label="Visible in the catalog" value={value} onValueChange={onChange} />
        )}
      />

      <Button onPress={handleSubmit((values) => onSave(values))} isLoading={isSubmitting}>
        {submitLabel}
      </Button>
    </View>
  );
}
