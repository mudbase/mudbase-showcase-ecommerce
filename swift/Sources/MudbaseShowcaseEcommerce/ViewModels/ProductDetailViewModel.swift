import Foundation

/// Mirrors `AddToCartForm.tsx`'s local quantity stepper + transient add-to-cart status.
@MainActor
final class ProductDetailViewModel: ObservableObject {
    enum AddToCartStatus: Equatable {
        case idle
        case adding
        case added
        case error(String)
    }

    let product: Product
    @Published var quantity = 1
    @Published private(set) var status: AddToCartStatus = .idle

    private let cartStore: CartStore

    init(product: Product, cartStore: CartStore) {
        self.product = product
        self.cartStore = cartStore
    }

    var isOutOfStock: Bool { product.stock <= 0 }
    var maxQuantity: Int { max(product.stock, 1) }

    func increment() { quantity = min(maxQuantity, quantity + 1) }
    func decrement() { quantity = max(1, quantity - 1) }

    func addToCart() async {
        status = .adding
        let item = CartItem(
            productId: product.id,
            name: product.name,
            priceCents: product.priceCents,
            currency: product.currency,
            imageUrl: product.imageUrl,
            quantity: quantity
        )
        let succeeded = await cartStore.addItem(item)
        if succeeded {
            status = .added
            try? await Task.sleep(for: .milliseconds(1500))
        } else {
            status = .error(cartStore.lastErrorMessage ?? "Something went wrong adding this to your cart. Please try again.")
            try? await Task.sleep(for: .milliseconds(2500))
        }
        status = .idle
    }
}
