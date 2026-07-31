import SwiftUI

/// Mirrors `products/[slug]/page.tsx` + `AddToCartForm.tsx`. Takes the already-fetched `Product`
/// (from the catalog grid or seller's product list) rather than re-fetching by slug — this app
/// always arrives here already holding the full product, unlike the web app's own route which
/// only has a slug in the URL.
struct ProductDetailView: View {
    @StateObject private var viewModel: ProductDetailViewModel

    /// `cartStore` is the app's single shared instance, passed down explicitly by the caller
    /// (rather than read via `@EnvironmentObject` here) so the dependency this screen has on the
    /// cart is visible at every call site — see `CatalogView`'s `navigationDestination`.
    init(product: Product, cartStore: CartStore) {
        _viewModel = StateObject(wrappedValue: ProductDetailViewModel(product: product, cartStore: cartStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ImageCarouselView(imageURLs: viewModel.product.allImageURLs)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if let category = viewModel.product.category {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                        if let discountPercent = viewModel.product.discountPercent {
                            Text("\(discountPercent)% off")
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text(viewModel.product.name)
                        .font(.title2.bold())

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Formatting.money(cents: viewModel.product.priceCents, currency: viewModel.product.currency))
                            .font(.title3.bold())
                        if let compareAtPriceCents = viewModel.product.compareAtPriceCents, viewModel.product.discountPercent != nil {
                            Text(Formatting.money(cents: compareAtPriceCents, currency: viewModel.product.currency))
                                .foregroundStyle(.secondary)
                                .strikethrough()
                        }
                    }
                }

                if let description = viewModel.product.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                }

                addToCartControl

                Text(viewModel.product.stock > 0 ? "\(viewModel.product.stock) in stock" : "Currently out of stock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(viewModel.product.name)
        .inlineNavigationTitle()
    }

    private var addToCartControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Stepper(value: $viewModel.quantity, in: 1...viewModel.maxQuantity) {
                    Text("Qty: \(viewModel.quantity)")
                }
                .disabled(viewModel.isOutOfStock)
                .fixedSize()

                Button {
                    Task { await viewModel.addToCart() }
                } label: {
                    addToCartLabel
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isOutOfStock || viewModel.status == .adding)
            }

            if case .error(let message) = viewModel.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var addToCartLabel: some View {
        switch viewModel.status {
        case .idle:
            Label(viewModel.isOutOfStock ? "Out of stock" : "Add to cart", systemImage: "bag.badge.plus")
        case .adding:
            ProgressView()
        case .added:
            Label("Added to cart", systemImage: "checkmark")
        case .error:
            Text("Couldn't add — try again")
        }
    }
}
