import Foundation
import MudbaseSDK

/// Order reads/writes against the `orders` collection. `customer` role: create/read/update own
/// only. `seller` role: read/update all (the fulfillment queue). Mirrors `checkout/page.tsx`'s
/// `placeOrder`, `OrderList.tsx`, and `SellerOrderQueue.tsx`.
struct OrdersService {
    private let gateway: CollectionsGateway

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.ordersCollectionId)
    }

    func listForUser(_ userId: String) async throws -> [Order] {
        let result = try await gateway.list(filter: ["userId": .string(userId)], sort: "-createdAt")
        return result.documents.map(Order.init(document:))
    }

    /// The seller fulfillment queue — every order, not scoped to a `userId`.
    func listAllForSeller(limit: Int = 100) async throws -> [Order] {
        let result = try await gateway.list(sort: "-createdAt", limit: limit)
        return result.documents.map(Order.init(document:))
    }

    func get(id: String) async throws -> Order {
        Order(document: try await gateway.get(documentId: id))
    }

    /// Creates the order document with `orderStatus: "awaiting_payment"` — the payment link is
    /// requested by the caller afterward via `PayLinkGateway`, matching the two-step flow in
    /// `checkout/page.tsx`'s `placeOrder` (order first, so it's visible in Orders even if the
    /// payment-link call subsequently fails).
    @discardableResult
    func create(userId: String, items: [CartItem], subtotalCents: Int, shippingAddress: ShippingAddress) async throws -> Order {
        let lineItems = items.map { OrderLineItem(productId: $0.productId, name: $0.name, priceCents: $0.priceCents, quantity: $0.quantity) }
        let doc = try await gateway.create(fields: [
            "userId": .string(userId),
            "itemsJson": .string(JSONField.stringify(lineItems)),
            "subtotalCents": .int(subtotalCents),
            "currency": .string("USD"),
            "orderStatus": .string(OrderStatus.awaitingPayment.rawValue),
            "shippingName": .string(shippingAddress.fullName),
            "shippingAddressJson": .string(JSONField.stringify(shippingAddress)),
            "paymentStatus": .string(OrderPaymentStatus.unpaid.rawValue),
        ])
        return Order(document: doc)
    }

    func setPaymentLinkToken(orderId: String, token: String) async throws {
        try await gateway.update(documentId: orderId, fields: ["paymentLinkToken": .string(token)])
    }

    /// Used both by the seller's "mark shipped/delivered" action and by checkout falling an order
    /// back to `pending` when the payment link couldn't be created because of a KYC gate.
    func setOrderStatus(orderId: String, status: OrderStatus) async throws {
        try await gateway.update(documentId: orderId, fields: ["orderStatus": .string(status.rawValue)])
    }
}
