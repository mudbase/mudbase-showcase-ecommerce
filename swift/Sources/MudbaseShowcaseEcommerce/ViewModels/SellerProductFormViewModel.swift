import Foundation

/// Mirrors `ProductForm.tsx`'s zod schema — re-implemented as plain validation since this project
/// has no zod dependency. Handles both "Add product" and "Edit product" (an `existingProduct`
/// switches the save path from `create` to `update`, exactly like `seller/products/new/page.tsx`
/// vs. `seller/products/[id]/edit/page.tsx`).
@MainActor
final class SellerProductFormViewModel: ObservableObject {
    @Published var draft: ProductDraft
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var didSave = false

    private let service: ProductsService
    private let sellerId: String
    private let existingProductId: String?

    init(config: AppConfig, sellerId: String, existingProduct: Product? = nil) {
        service = ProductsService(config: config)
        self.sellerId = sellerId
        existingProductId = existingProduct?.id
        draft = existingProduct.map(ProductDraft.init(product:)) ?? ProductDraft()
    }

    var isEditing: Bool { existingProductId != nil }

    private var validationError: String? {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Name is required" }
        if draft.priceCents < 0 { return "Price can't be negative" }
        if draft.stock < 0 { return "Stock can't be negative" }
        if let compareAt = draft.compareAtPriceCents, compareAt <= draft.priceCents {
            return "Compare-at price must be higher than the current price"
        }
        if !draft.imageUrl.isEmpty && URL(string: draft.imageUrl) == nil {
            return "Enter a valid image URL"
        }
        if draft.galleryURLs.count > ProductDraft.maxGalleryPhotos {
            return "Up to \(ProductDraft.maxGalleryPhotos) extra photos"
        }
        for url in draft.galleryURLs where !url.isEmpty && URL(string: url) == nil {
            return "Enter a valid image URL"
        }
        return nil
    }

    var canAddGalleryPhoto: Bool { draft.galleryURLs.count < ProductDraft.maxGalleryPhotos }

    func addGalleryField() {
        guard canAddGalleryPhoto else { return }
        draft.galleryURLs.append("")
    }

    func removeGalleryField(at index: Int) {
        guard draft.galleryURLs.indices.contains(index) else { return }
        draft.galleryURLs.remove(at: index)
    }

    func save() async {
        if let validationError {
            errorMessage = validationError
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            if let existingProductId {
                try await service.update(id: existingProductId, draft: draft)
            } else {
                try await service.create(draft: draft, sellerId: sellerId)
            }
            didSave = true
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }
}
