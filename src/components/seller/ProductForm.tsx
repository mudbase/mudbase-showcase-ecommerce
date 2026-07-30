"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

const schema = z.object({
  name: z.string().min(1, "Name is required"),
  description: z.string().optional(),
  priceCents: z.coerce.number().int().min(0, "Price can't be negative"),
  currency: z.string().min(1),
  imageUrl: z.string().url("Enter a valid image URL").or(z.literal("")),
  category: z.string().optional(),
  stock: z.coerce.number().int().min(0, "Stock can't be negative"),
  isActive: z.boolean(),
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
      ...initialValues,
    },
  })

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
        <Input id="description" {...register("description")} />
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
        <Label htmlFor="category">Category</Label>
        <Input id="category" {...register("category")} />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="imageUrl">Image URL</Label>
        <Input id="imageUrl" placeholder="https://…" {...register("imageUrl")} />
        {errors.imageUrl && <p className="text-xs text-destructive">{errors.imageUrl.message}</p>}
        <p className="text-xs text-muted-foreground">
          Mudbase file uploads require an owner/admin/developer role, which project end-users (sellers included)
          don&apos;t have — see README &ldquo;Known limitations&rdquo;. Paste a hosted image URL for now.
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
