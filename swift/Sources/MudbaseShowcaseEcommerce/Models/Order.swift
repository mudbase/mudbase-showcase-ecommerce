import Foundation

/// Mirrors `web/src/types/order.ts`.
struct OrderLineItem: Sendable, Equatable, Codable, Identifiable {
    var productId: String
    var name: String
    var priceCents: Int
    var quantity: Int

    var id: String { productId }
    var lineTotalCents: Int { priceCents * quantity }
}

struct ShippingAddress: Sendable, Equatable, Codable {
    var fullName: String
    var line1: String
    var line2: String?
    var city: String
    var region: String
    var postalCode: String
    var country: String
}

enum OrderStatus: String, Sendable, Equatable, Codable, CaseIterable {
    case pending
    case awaitingPayment = "awaiting_payment"
    case paid
    case shipped
    case delivered
    case cancelled

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .awaitingPayment: return "Awaiting payment"
        case .paid: return "Paid"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }

    /// Matches `SellerOrderQueue.tsx`'s `NEXT_STATUS` map — the only forward transition a seller
    /// can trigger with one tap from the fulfillment queue.
    var nextFulfillmentStatus: OrderStatus? {
        switch self {
        case .paid: return .shipped
        case .shipped: return .delivered
        default: return nil
        }
    }
}

enum OrderPaymentStatus: String, Sendable, Equatable, Codable {
    case unpaid
    case paid
    case expired
    case cancelled
}

/// Field named `orderStatus`, not `status` — Mudbase's server-side role-assignment guard treats a
/// literal `status` field on ANY collection as a protected role field and rejects writes from every
/// project end-user (sellers included). Real platform constraint carried over verbatim from
/// `web/src/types/order.ts` — see README "Known limitations".
struct Order: Sendable, Equatable, Identifiable {
    let id: String
    let createdAt: Date?
    let userId: String
    let itemsJson: String
    let subtotalCents: Int
    let currency: String
    let orderStatus: OrderStatus
    let shippingName: String?
    let shippingAddressJson: String?
    let paymentLinkToken: String?
    let paymentStatus: OrderPaymentStatus

    var items: [OrderLineItem] { JSONField.parse(itemsJson, as: [OrderLineItem].self, fallback: []) }
    var shippingAddress: ShippingAddress? { JSONField.parse(shippingAddressJson, as: ShippingAddress?.self, fallback: nil) }

    var shortId: String { String(id.suffix(6)).uppercased() }

    init(document: MudbaseDocument) {
        id = document.id
        createdAt = document.createdAt
        userId = document.string("userId") ?? ""
        itemsJson = document.string("itemsJson") ?? "[]"
        subtotalCents = document.int("subtotalCents") ?? 0
        currency = document.string("currency") ?? "USD"
        orderStatus = (document.string("orderStatus")).flatMap(OrderStatus.init(rawValue:)) ?? .pending
        shippingName = document.string("shippingName")
        shippingAddressJson = document.string("shippingAddressJson")
        paymentLinkToken = document.string("paymentLinkToken")
        paymentStatus = (document.string("paymentStatus")).flatMap(OrderPaymentStatus.init(rawValue:)) ?? .unpaid
    }
}
