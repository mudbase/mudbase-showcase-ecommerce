import Foundation

/// Mirrors `ProductTable.tsx` — the seller's own catalog, unfiltered by `isActive`.
@MainActor
final class SellerProductListViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?
    @Published private(set) var deletingProductId: String?

    private let service: ProductsService

    init(config: AppConfig) {
        service = ProductsService(config: config)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            products = try await service.listAll()
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }

    func delete(_ product: Product) async {
        deletingProductId = product.id
        defer { deletingProductId = nil }
        do {
            try await service.delete(id: product.id)
            products.removeAll { $0.id == product.id }
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
