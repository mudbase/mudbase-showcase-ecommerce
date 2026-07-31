import Foundation

/// Mirrors `SellerOrderQueue.tsx`: every order (no `userId` scope), with a one-tap forward
/// transition (`paid` → `shipped` → `delivered`) per `OrderStatus.nextFulfillmentStatus`.
@MainActor
final class SellerOrderQueueViewModel: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?
    @Published private(set) var updatingOrderId: String?

    private let service: OrdersService

    init(config: AppConfig) {
        service = OrdersService(config: config)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            orders = try await service.listAllForSeller()
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }

    func advance(_ order: Order) async {
        guard let next = order.orderStatus.nextFulfillmentStatus else { return }
        updatingOrderId = order.id
        defer { updatingOrderId = nil }
        do {
            try await service.setOrderStatus(orderId: order.id, status: next)
            await load()
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
