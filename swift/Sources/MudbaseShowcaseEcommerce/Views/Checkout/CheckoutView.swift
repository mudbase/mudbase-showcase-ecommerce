import SwiftUI

/// Mirrors `checkout/page.tsx` + `ShippingForm.tsx`. This app requires login before browsing at
/// all, so unlike the web page there is no inline "register/sign in to continue" branch here — the
/// shopper is always already a signed-in customer by the time they reach checkout.
struct CheckoutView: View {
    @StateObject private var viewModel: CheckoutViewModel
    private let items: [CartItem]
    private let subtotalCents: Int
    @State private var paymentToken: String?
    private let config: AppConfig

    init(config: AppConfig, cartStore: CartStore, userId: String) {
        self.config = config
        items = cartStore.items
        subtotalCents = cartStore.subtotalCents
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(config: config, cartStore: cartStore, userId: userId))
    }

    var body: some View {
        Form {
            if let errorMessage = viewModel.errorMessage {
                Section { InlineBanner(message: errorMessage) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Order summary") {
                OrderSummaryView(items: items, subtotalCents: subtotalCents)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Shipping address") {
                TextField("Full name", text: $viewModel.fullName)
                    .textContentType(.name)
                TextField("Address", text: $viewModel.line1)
                    .textContentType(.streetAddressLine1)
                TextField("Apartment, suite, etc. (optional)", text: $viewModel.line2)
                    .textContentType(.streetAddressLine2)
                TextField("City", text: $viewModel.city)
                    .textContentType(.addressCity)
                TextField("State / region", text: $viewModel.region)
                    .textContentType(.addressState)
                TextField("Postal code", text: $viewModel.postalCode)
                    .textContentType(.postalCode)
                TextField("Country", text: $viewModel.country)
                    .textContentType(.countryName)
            }

            Section {
                Button {
                    Task { await viewModel.placeOrder() }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Continue to payment")
                    }
                }
                .disabled(!viewModel.canSubmit)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Checkout")
        .onChange(of: viewModel.paymentLinkToken) { _, newValue in
            paymentToken = newValue
        }
        .navigationDestination(item: $paymentToken) { token in
            PaymentStatusView(config: config, token: token)
        }
    }
}
