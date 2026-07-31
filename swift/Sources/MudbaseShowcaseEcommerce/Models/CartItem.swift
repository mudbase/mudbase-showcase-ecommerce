import Foundation

/// Mirrors `web/src/types/cart.ts`. Encoded/decoded as a JSON array inside the `carts` collection's
/// `itemsJson` string field (see `Support/JSONField.swift`).
struct CartItem: Sendable, Equatable, Identifiable, Codable {
    var productId: String
    var name: String
    var priceCents: Int
    var currency: String
    var imageUrl: String?
    var quantity: Int

    var id: String { productId }
    var lineTotalCents: Int { priceCents * quantity }
}

/// The `carts` collection document — one per user (`customer` role: full CRUD, own only).
struct CartRecord: Sendable, Equatable, Identifiable {
    let id: String
    let userId: String
    let itemsJson: String

    var items: [CartItem] { JSONField.parse(itemsJson, as: [CartItem].self, fallback: []) }

    init(document: MudbaseDocument) {
        id = document.id
        userId = document.string("userId") ?? ""
        itemsJson = document.string("itemsJson") ?? "[]"
    }
}
