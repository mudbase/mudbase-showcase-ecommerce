import SwiftUI

/// Mirrors `ProductTable.tsx`.
struct SellerProductListView: View {
    @StateObject private var viewModel: SellerProductListViewModel
    private let config: AppConfig
    private let sellerId: String
    @State private var isPresentingNewProduct = false

    init(config: AppConfig, sellerId: String) {
        self.config = config
        self.sellerId = sellerId
        _viewModel = StateObject(wrappedValue: SellerProductListViewModel(config: config))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if viewModel.products.isEmpty {
                VStack(spacing: 12) {
                    Text("No products listed yet.")
                        .foregroundStyle(.secondary)
                    Button("Add your first product") { isPresentingNewProduct = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else {
                List {
                    ForEach(viewModel.products) { product in
                        NavigationLink(value: product) {
                            row(for: product)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.delete(product) }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add product", systemImage: "plus") { isPresentingNewProduct = true }
            }
        }
        .navigationDestination(for: Product.self) { product in
            SellerProductFormView(config: config, sellerId: sellerId, existingProduct: product)
        }
        .sheet(isPresented: $isPresentingNewProduct, onDismiss: { Task { await viewModel.load() } }) {
            NavigationStack {
                SellerProductFormView(config: config, sellerId: sellerId, existingProduct: nil)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(for product: Product) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .lineLimit(1)
                Text("\(product.stock) in stock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if let discountPercent = product.discountPercent, let compareAt = product.compareAtPriceCents {
                        Text(Formatting.money(cents: compareAt, currency: product.currency))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                        Text("-\(discountPercent)%")
                            .font(.caption2.bold())
                    }
                    Text(Formatting.money(cents: product.priceCents, currency: product.currency))
                }
                Text(product.isActive ? "Active" : "Hidden")
                    .font(.caption2)
                    .foregroundStyle(product.isActive ? .green : .secondary)
            }
        }
    }
}
