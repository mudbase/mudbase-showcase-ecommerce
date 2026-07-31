import Foundation
import MudbaseSDK

/// Server-backed cart for the signed-in `customer`, one document per user in the `carts`
/// collection (`customer` role: full CRUD, own only). The Swift equivalent of `useCart.ts` minus
/// the guest/localStorage branch and its migration-on-registration dance — this app requires login
/// before browsing at all, so there is never a pre-account cart to merge in.
@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    private let gateway: CollectionsGateway
    private var userId: String?

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.cartsCollectionId)
    }

    var subtotalCents: Int { items.reduce(0) { $0 + $1.lineTotalCents } }
    var isEmpty: Bool { items.isEmpty }

    /// Call once the signed-in user is known (or changes) — loads that user's cart.
    func bind(userId: String) async {
        guard self.userId != userId else { return }
        self.userId = userId
        await reload()
    }

    /// Call on logout so the next signed-in user never sees a stale cart from a previous session.
    func clearBinding() {
        userId = nil
        items = []
    }

    func reload() async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await gateway.list(filter: ["userId": .string(userId)])
            items = result.documents.first.map { CartRecord(document: $0).items } ?? []
        } catch {
            lastErrorMessage = MudbaseAPIError.map(error).message
        }
    }

    @discardableResult
    func addItem(_ item: CartItem) async -> Bool {
        var next = items
        if let index = next.firstIndex(where: { $0.productId == item.productId }) {
            next[index].quantity += item.quantity
        } else {
            next.append(item)
        }
        return await persist(next)
    }

    @discardableResult
    func updateQuantity(productId: String, quantity: Int) async -> Bool {
        var next = items
        if quantity <= 0 {
            next.removeAll { $0.productId == productId }
        } else if let index = next.firstIndex(where: { $0.productId == productId }) {
            next[index].quantity = quantity
        }
        return await persist(next)
    }

    @discardableResult
    func removeItem(productId: String) async -> Bool {
        await persist(items.filter { $0.productId != productId })
    }

    @discardableResult
    func clear() async -> Bool {
        await persist([])
    }

    /// Re-fetches the authoritative cart right before deciding create-vs-update rather than
    /// trusting a locally cached document id — mirrors the same re-fetch in `useCart.ts`'s
    /// `persist` mutation, which exists to avoid creating a duplicate cart document if this app's
    /// own state and the server ever drift (e.g. a stale local id after a previous unexpected
    /// failure). Returns whether the write succeeded so callers with per-action UI feedback (e.g.
    /// "Add to cart" button state) don't have to infer success from a shared error field.
    @discardableResult
    private func persist(_ nextItems: [CartItem]) async -> Bool {
        guard let userId else { return false }
        let itemsJson = JSONField.stringify(nextItems)
        do {
            let result = try await gateway.list(filter: ["userId": .string(userId)])
            if let existing = result.documents.first {
                _ = try await gateway.update(documentId: existing.id, fields: ["itemsJson": .string(itemsJson)])
            } else {
                _ = try await gateway.create(fields: ["userId": .string(userId), "itemsJson": .string(itemsJson)])
            }
            items = nextItems
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = MudbaseAPIError.map(error).message
            return false
        }
    }
}
