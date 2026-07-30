import { CartLineItems } from "@/components/cart/CartLineItems"
import { CartSummary } from "@/components/cart/CartSummary"

export default function CartPage(): React.JSX.Element {
  return (
    <div className="container grid grid-cols-1 gap-10 py-10 lg:grid-cols-3">
      <div className="lg:col-span-2">
        <h1 className="mb-6 font-display text-2xl font-semibold tracking-tight">Your cart</h1>
        <CartLineItems />
      </div>
      <div>
        <CartSummary />
      </div>
    </div>
  )
}
