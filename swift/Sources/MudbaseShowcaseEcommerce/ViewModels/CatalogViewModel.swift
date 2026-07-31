import Foundation

/// Mirrors `ProductGrid.tsx`: re-fetches from the server on every category change (rather than
/// filtering a client-side superset) and derives the category pill list from whatever the current
/// fetch returned — the same behavior the web version has, quirks included.
@MainActor
final class CatalogViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var selectedCategory: String? {
        didSet {
            guard oldValue != selectedCategory else { return }
            Task { await self.load() }
        }
    }
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let service: ProductsService

    init(config: AppConfig) {
        service = ProductsService(config: config)
    }

    var categories: [String] {
        Array(Set(products.compactMap(\.category))).sorted()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            products = try await service.listActive(category: selectedCategory)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
