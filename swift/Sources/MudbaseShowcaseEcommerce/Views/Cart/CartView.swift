import SwiftUI

/// Mirrors `cart/page.tsx` (`CartLineItems.tsx` + `CartSummary.tsx`).
struct CartView: View {
    @EnvironmentObject private var cartStore: CartStore
    @EnvironmentObject private var sessionStore: SessionStore
    private let config: AppConfig
    @State private var showingCheckout = false

    init(config: AppConfig) {
        self.config = config
    }

    var body: some View {
        Group {
            if cartStore.isEmpty {
                EmptyStateView(message: "Your cart is empty.")
            } else {
                List {
                    Section {
                        ForEach(cartStore.items) { item in
                            CartLineItemView(
                                item: item,
                                onIncrement: { Task { await cartStore.updateQuantity(productId: item.productId, quantity: item.quantity + 1) } },
                                onDecrement: { Task { await cartStore.updateQuantity(productId: item.productId, quantity: item.quantity - 1) } },
                                onRemove: { Task { await cartStore.removeItem(productId: item.productId) } }
                            )
                        }
                    }

                    Section {
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text(Formatting.money(cents: cartStore.subtotalCents, currency: cartStore.items.first?.currency ?? "USD"))
                                .font(.headline)
                        }
                        Button("Checkout") { showingCheckout = true }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Cart")
        .task { await cartStore.reload() }
        .navigationDestination(isPresented: $showingCheckout) {
            if let userId = sessionStore.user?.id {
                CheckoutView(config: config, cartStore: cartStore, userId: userId)
            }
        }
    }
}
