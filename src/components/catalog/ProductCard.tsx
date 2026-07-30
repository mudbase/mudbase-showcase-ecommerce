import Image from "next/image"
import Link from "next/link"
import { formatMoney } from "@/lib/utils"
import type { Product } from "@/types/product"
import { Card, CardContent, CardFooter } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

export function ProductCard({ product }: { product: Product }): React.JSX.Element {
  const outOfStock = product.stock <= 0

  return (
    <Link href={`/products/${product.slug}`} className="group block">
      <Card className="overflow-hidden transition-shadow group-hover:shadow-md">
        <div className="relative aspect-square bg-muted">
          {product.imageUrl ? (
            <Image
              src={product.imageUrl}
              alt={product.name}
              fill
              sizes="(min-width: 1024px) 25vw, (min-width: 640px) 33vw, 50vw"
              className="object-cover transition-transform group-hover:scale-105"
            />
          ) : (
            <div className="flex h-full items-center justify-center text-sm text-muted-foreground">No image</div>
          )}
          {outOfStock && (
            <Badge variant="secondary" className="absolute left-2 top-2">
              Out of stock
            </Badge>
          )}
        </div>
        <CardContent className="p-4">
          <p className="text-xs uppercase tracking-wide text-muted-foreground">{product.category || "General"}</p>
          <h3 className="mt-1 line-clamp-1 font-medium">{product.name}</h3>
        </CardContent>
        <CardFooter className="px-4 pb-4 pt-0">
          <span className="font-semibold tabular-nums">{formatMoney(product.priceCents, product.currency)}</span>
        </CardFooter>
      </Card>
    </Link>
  )
}
