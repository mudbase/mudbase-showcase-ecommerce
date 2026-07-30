import { ProductGrid } from "@/components/catalog/ProductGrid"

export default function HomePage(): React.JSX.Element {
  return (
    <div className="container py-10">
      <div className="mb-8 space-y-2">
        <h1 className="font-display text-3xl font-semibold tracking-tight">Commonwealth Goods</h1>
        <p className="max-w-2xl text-muted-foreground">
          Every product, order, cart, and payment on this page is served by a real Mudbase project — no custom
          backend. Browse as a guest; your cart follows you the moment you sign in.
        </p>
      </div>
      <ProductGrid />
    </div>
  )
}
