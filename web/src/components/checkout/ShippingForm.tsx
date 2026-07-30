"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import type { ShippingAddress } from "@/types/order"

export const shippingSchema = z.object({
  fullName: z.string().min(1, "Full name is required"),
  line1: z.string().min(1, "Address is required"),
  line2: z.string().optional(),
  city: z.string().min(1, "City is required"),
  region: z.string().min(1, "State/region is required"),
  postalCode: z.string().min(1, "Postal code is required"),
  country: z.string().min(1, "Country is required"),
})

interface ShippingFormProps {
  onSubmit: (address: ShippingAddress) => Promise<void>
  submitting: boolean
}

export function ShippingForm({ onSubmit, submitting }: ShippingFormProps): React.JSX.Element {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ShippingAddress>({ resolver: zodResolver(shippingSchema) })

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
      <div className="space-y-1.5">
        <Label htmlFor="fullName">Full name</Label>
        <Input id="fullName" autoComplete="name" {...register("fullName")} />
        {errors.fullName && <p className="text-xs text-destructive">{errors.fullName.message}</p>}
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="line1">Address</Label>
        <Input id="line1" autoComplete="address-line1" {...register("line1")} />
        {errors.line1 && <p className="text-xs text-destructive">{errors.line1.message}</p>}
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="line2">Apartment, suite, etc. (optional)</Label>
        <Input id="line2" autoComplete="address-line2" {...register("line2")} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="city">City</Label>
          <Input id="city" autoComplete="address-level2" {...register("city")} />
          {errors.city && <p className="text-xs text-destructive">{errors.city.message}</p>}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="region">State / region</Label>
          <Input id="region" autoComplete="address-level1" {...register("region")} />
          {errors.region && <p className="text-xs text-destructive">{errors.region.message}</p>}
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="postalCode">Postal code</Label>
          <Input id="postalCode" autoComplete="postal-code" {...register("postalCode")} />
          {errors.postalCode && <p className="text-xs text-destructive">{errors.postalCode.message}</p>}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="country">Country</Label>
          <Input id="country" autoComplete="country-name" {...register("country")} />
          {errors.country && <p className="text-xs text-destructive">{errors.country.message}</p>}
        </div>
      </div>
      <Button type="submit" className="w-full" disabled={submitting}>
        {submitting ? "Placing order…" : "Continue to payment"}
      </Button>
    </form>
  )
}
