import Foundation
import MudbaseSDK

/// Catalog reads (any authenticated role) plus seller-only product management, all against the
/// `products` collection. Mirrors `ProductGrid.tsx`/`ProductDetailPage` for reads and
/// `ProductForm.tsx` + the seller product pages for writes.
struct ProductsService {
    private let gateway: CollectionsGateway

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.productsCollectionId)
    }

    func listActive(category: String? = nil) async throws -> [Product] {
        var filter: [String: JSONValue] = ["isActive": .bool(true)]
        if let category, !category.isEmpty { filter["category"] = .string(category) }
        let result = try await gateway.list(filter: filter, sort: "-createdAt", limit: 60)
        return result.documents.map(Product.init(document:))
    }

    func find(bySlug slug: String) async throws -> Product? {
        let result = try await gateway.list(filter: ["slug": .string(slug)])
        return result.documents.first.map(Product.init(document:))
    }

    /// Seller's own product list — no `isActive` filter, so hidden/out-of-stock products still show.
    func listAll(limit: Int = 100) async throws -> [Product] {
        let result = try await gateway.list(sort: "-createdAt", limit: limit)
        return result.documents.map(Product.init(document:))
    }

    func get(id: String) async throws -> Product {
        Product(document: try await gateway.get(documentId: id))
    }

    @discardableResult
    func create(draft: ProductDraft, sellerId: String) async throws -> Product {
        let slug = "\(Formatting.slugify(draft.name))-\(Self.randomSlugSuffix())"
        let fields = Self.fields(for: draft, slugOverride: slug, sellerId: sellerId)
        return Product(document: try await gateway.create(fields: fields))
    }

    @discardableResult
    func update(id: String, draft: ProductDraft) async throws -> Product {
        let fields = Self.fields(for: draft, slugOverride: nil, sellerId: nil)
        return Product(document: try await gateway.update(documentId: id, fields: fields))
    }

    func delete(id: String) async throws {
        try await gateway.delete(documentId: id)
    }

    private static func fields(for draft: ProductDraft, slugOverride: String?, sellerId: String?) -> [String: JSONValue?] {
        let galleryJson = JSONField.stringify(draft.galleryURLs.filter { !$0.isEmpty })
        var fields: [String: JSONValue?] = [
            "name": .string(draft.name),
            "description": draft.description.isEmpty ? nil : .string(draft.description),
            "priceCents": .int(draft.priceCents),
            "compareAtPriceCents": draft.compareAtPriceCents.map(JSONValue.int),
            "currency": .string(draft.currency),
            "imageUrl": draft.imageUrl.isEmpty ? nil : .string(draft.imageUrl),
            "galleryJson": .string(galleryJson),
            "category": draft.category.isEmpty ? nil : .string(draft.category),
            "stock": .int(draft.stock),
            "isActive": .bool(draft.isActive),
        ]
        if let slugOverride { fields["slug"] = .string(slugOverride) }
        if let sellerId { fields["sellerId"] = .string(sellerId) }
        return fields
    }

    private static func randomSlugSuffix(length: Int = 6) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
