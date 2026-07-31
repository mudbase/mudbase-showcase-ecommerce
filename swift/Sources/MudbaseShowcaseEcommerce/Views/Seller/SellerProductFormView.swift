import SwiftUI

/// Mirrors `ProductForm.tsx` — handles both "Add product" and "Edit product".
struct SellerProductFormView: View {
    @StateObject private var viewModel: SellerProductFormViewModel
    @Environment(\.dismiss) private var dismiss

    init(config: AppConfig, sellerId: String, existingProduct: Product?) {
        _viewModel = StateObject(wrappedValue: SellerProductFormViewModel(config: config, sellerId: sellerId, existingProduct: existingProduct))
    }

    var body: some View {
        Form {
            if let errorMessage = viewModel.errorMessage {
                Section { InlineBanner(message: errorMessage) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Details") {
                TextField("Name", text: $viewModel.draft.name)
                TextField("Description", text: $viewModel.draft.description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Category", text: $viewModel.draft.category)
            }

            Section("Pricing & stock") {
                LabeledContent("Price (cents)") {
                    TextField("0", value: $viewModel.draft.priceCents, format: .number)
                        .numberPadKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Compare-at price (cents)") {
                    TextField("None", value: $viewModel.draft.compareAtPriceCents, format: .number)
                        .numberPadKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Stock") {
                    TextField("0", value: $viewModel.draft.stock, format: .number)
                        .numberPadKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                TextField("Currency", text: $viewModel.draft.currency)
                Text("Set a compare-at price higher than the price to show a strikethrough & discount badge in the catalog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Photos") {
                TextField("Main image URL", text: $viewModel.draft.imageUrl)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                Text("Paste a hosted image URL — Mudbase file uploads require an owner/admin/developer role, which sellers don't have (see README \"Known limitations\").")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.draft.galleryURLs.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField("https://…", text: Binding(
                            get: { viewModel.draft.galleryURLs[index] },
                            set: { viewModel.draft.galleryURLs[index] = $0 }
                        ))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        Button(role: .destructive) {
                            viewModel.removeGalleryField(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if viewModel.canAddGalleryPhoto {
                    Button("Add photo", systemImage: "plus") { viewModel.addGalleryField() }
                }
            }

            Section {
                Toggle("Visible in the catalog", isOn: $viewModel.draft.isActive)
            }

            Section {
                Button {
                    Task {
                        await viewModel.save()
                        if viewModel.didSave { dismiss() }
                    }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Save product")
                    }
                }
                .disabled(viewModel.isSubmitting)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit product" : "Add product")
        .inlineNavigationTitle()
    }
}
