"use client"

import { useForm, useFieldArray } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useRouter } from "next/navigation"
import { Plus, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

const MAX_GALLERY_PHOTOS = 8

const schema = z
  .object({
    name: z.string().min(1, "Name is required"),
    description: z.string().optional(),
    priceCents: z.coerce.number().int().min(0, "Price can't be negative"),
    compareAtPriceCents: z.preprocess(
      (value) => (value === "" || value === undefined || value === null ? undefined : Number(value)),
      z.number().int().min(0).optional(),
    ),
    currency: z.string().min(1),
    imageUrl: z.string().url("Enter a valid image URL").or(z.literal("")),
    galleryUrls: z
      .array(z.object({ url: z.string().url("Enter a valid image URL") }))
      .max(MAX_GALLERY_PHOTOS, `Up to ${MAX_GALLERY_PHOTOS} extra photos`),
    category: z.string().optional(),
    stock: z.coerce.number().int().min(0, "Stock can't be negative"),
    isActive: z.boolean(),
  })
  .refine((data) => data.compareAtPriceCents === undefined || data.compareAtPriceCents > data.priceCents, {
    message: "Compare-at price must be higher than the current price",
    path: ["compareAtPriceCents"],
  })

export type ProductFormValues = z.infer<typeof schema>

interface ProductFormProps {
  initialValues?: Partial<ProductFormValues>
  onSave: (values: ProductFormValues) => Promise<void>
}

export function ProductForm({ initialValues, onSave }: ProductFormProps): React.JSX.Element {
  const router = useRouter()
  const {
    register,
    control,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ProductFormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      currency: "USD",
      isActive: true,
      priceCents: 0,
      stock: 0,
      imageUrl: "",
      galleryUrls: [],
      ...initialValues,
    },
  })

  const { fields, append, remove } = useFieldArray({ control, name: "galleryUrls" })

  const onSubmit = async (values: ProductFormValues): Promise<void> => {
    await onSave(values)
    router.push("/seller")
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="max-w-lg space-y-4" noValidate>
      <div className="space-y-1.5">
        <Label htmlFor="name">Name</Label>
        <Input id="name" {...register("name")} />
        {errors.name && <p className="text-xs text-destructive">{errors.name.message}</p>}
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea id="description" rows={5} {...register("description")} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="priceCents">Price (cents)</Label>
          <Input id="priceCents" type="number" {...register("priceCents")} />
          {errors.priceCents && <p className="text-xs text-destructive">{errors.priceCents.message}</p>}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="stock">Stock</Label>
          <Input id="stock" type="number" {...register("stock")} />
          {errors.stock && <p className="text-xs text-destructive">{errors.stock.message}</p>}
        </div>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="compareAtPriceCents">Compare-at price (cents)</Label>
        <Input
          id="compareAtPriceCents"
          type="number"
          placeholder="Leave blank for no discount"
          {...register("compareAtPriceCents")}
        />
        {errors.compareAtPriceCents && (
          <p className="text-xs text-destructive">{errors.compareAtPriceCents.message}</p>
        )}
        <p className="text-xs text-muted-foreground">
          Set this higher than the price to show a strikethrough &amp; discount badge in the catalog.
        </p>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="category">Category</Label>
        <Input id="category" {...register("category")} />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="imageUrl">Main image URL</Label>
        <Input id="imageUrl" placeholder="https://…" {...register("imageUrl")} />
        {errors.imageUrl && <p className="text-xs text-destructive">{errors.imageUrl.message}</p>}
        <p className="text-xs text-muted-foreground">
          Mudbase file uploads require an owner/admin/developer role, which project end-users (sellers included)
          don&apos;t have — see README &ldquo;Known limitations&rdquo;. Paste a hosted image URL for now.
        </p>
      </div>

      <div className="space-y-1.5">
        <Label>Additional photos</Label>
        <div className="space-y-2">
          {fields.map((field, index) => (
            <div key={field.id} className="flex items-start gap-2">
              <div className="flex-1">
                <Input placeholder="https://…" {...register(`galleryUrls.${index}.url` as const)} />
                {errors.galleryUrls?.[index]?.url && (
                  <p className="mt-1 text-xs text-destructive">{errors.galleryUrls[index]?.url?.message}</p>
                )}
              </div>
              <Button type="button" variant="ghost" size="icon" aria-label="Remove photo" onClick={() => remove(index)}>
                <X className="h-4 w-4" />
              </Button>
            </div>
          ))}
        </div>
        {fields.length < MAX_GALLERY_PHOTOS && (
          <Button type="button" variant="outline" size="sm" onClick={() => append({ url: "" })}>
            <Plus className="mr-1 h-4 w-4" />
            Add photo
          </Button>
        )}
        <p className="text-xs text-muted-foreground">
          Shown as a rotating gallery on the product page — shoppers can also click through photos manually.
        </p>
      </div>

      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" className="h-4 w-4 rounded border-input" {...register("isActive")} />
        Visible in the catalog
      </label>
      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Saving…" : "Save product"}
      </Button>
    </form>
  )
}
