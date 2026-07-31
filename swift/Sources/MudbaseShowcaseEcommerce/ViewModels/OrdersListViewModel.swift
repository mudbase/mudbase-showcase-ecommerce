import Foundation

/// Mirrors `OrderList.tsx`.
@MainActor
final class OrdersListViewModel: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let service: OrdersService
    private let userId: String

    init(config: AppConfig, userId: String) {
        service = OrdersService(config: config)
        self.userId = userId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            orders = try await service.listForUser(userId)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
