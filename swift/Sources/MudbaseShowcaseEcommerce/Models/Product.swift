import Foundation

/// Mirrors `web/src/types/product.ts`'s `Product` interface. `galleryJson` is a JSON-encoded
/// `[String]` of extra photo URLs (see `Support/JSONField.swift`) — Mudbase Collections have no
/// native array field type.
struct Product: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let priceCents: Int
    let compareAtPriceCents: Int?
    let currency: String
    let imageUrl: String?
    let galleryJson: String?
    let category: String?
    let stock: Int
    let isActive: Bool
    let sellerId: String?

    var gallery: [String] { JSONField.parse(galleryJson, as: [String].self, fallback: []) }

    /// All images in display order: main image first, then the gallery.
    var allImageURLs: [String] {
        ([imageUrl].compactMap { $0 } + gallery).filter { !$0.isEmpty }
    }

    var discountPercent: Int? {
        Formatting.discountPercent(priceCents: priceCents, compareAtPriceCents: compareAtPriceCents)
    }

    init(document: MudbaseDocument) {
        id = document.id
        name = document.string("name") ?? ""
        slug = document.string("slug") ?? ""
        description = document.string("description")
        priceCents = document.int("priceCents") ?? 0
        compareAtPriceCents = document.int("compareAtPriceCents")
        currency = document.string("currency") ?? "USD"
        imageUrl = document.string("imageUrl")
        galleryJson = document.string("galleryJson")
        category = document.string("category")
        stock = document.int("stock") ?? 0
        isActive = document.bool("isActive") ?? true
        sellerId = document.string("sellerId")
    }
}

/// Draft state for the seller's create/edit product form — the Swift equivalent of the web app's
/// zod-validated `ProductFormValues` (`web/src/components/seller/ProductForm.tsx`). Validation is
/// re-implemented in `SellerProductFormViewModel` since this project has no zod dependency.
struct ProductDraft: Equatable {
    var name = ""
    var description = ""
    var priceCents = 0
    var compareAtPriceCents: Int?
    var currency = "USD"
    var imageUrl = ""
    var galleryURLs: [String] = []
    var category = ""
    var stock = 0
    var isActive = true

    static let maxGalleryPhotos = 8

    init() {}

    init(product: Product) {
        name = product.name
        description = product.description ?? ""
        priceCents = product.priceCents
        compareAtPriceCents = product.compareAtPriceCents
        currency = product.currency
        imageUrl = product.imageUrl ?? ""
        galleryURLs = product.gallery
        category = product.category ?? ""
        stock = product.stock
        isActive = product.isActive
    }
}
