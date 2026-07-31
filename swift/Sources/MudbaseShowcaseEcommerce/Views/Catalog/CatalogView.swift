import SwiftUI

/// Mirrors `ProductGrid.tsx` (`page.tsx`'s home page).
struct CatalogView: View {
    @StateObject private var viewModel: CatalogViewModel
    @EnvironmentObject private var cartStore: CartStore

    init(config: AppConfig) {
        _viewModel = StateObject(wrappedValue: CatalogViewModel(config: config))
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        content
            .navigationTitle("Commonwealth Goods")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            InlineErrorView(message: errorMessage) {
                Task { await viewModel.load() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.categories.isEmpty {
                        CategoryFilterView(categories: viewModel.categories, selected: $viewModel.selectedCategory)
                            .padding(.horizontal)
                    }

                    if viewModel.products.isEmpty {
                        EmptyStateView(
                            message: viewModel.selectedCategory.map { "No products in \"\($0)\" yet." }
                                ?? "No products listed yet — check back soon."
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.products) { product in
                                NavigationLink(value: product) {
                                    ProductCardView(product: product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product, cartStore: cartStore)
            }
        }
    }
}
