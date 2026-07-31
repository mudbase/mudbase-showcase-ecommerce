import Foundation

/// Mirrors `orders/[id]/page.tsx`.
@MainActor
final class OrderDetailViewModel: ObservableObject {
    @Published private(set) var order: Order?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let service: OrdersService
    let orderId: String

    init(config: AppConfig, orderId: String) {
        service = OrdersService(config: config)
        self.orderId = orderId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            order = try await service.get(id: orderId)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
