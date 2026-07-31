import Foundation

/// Mirrors `checkout/page.tsx`'s `placeOrder`: create the order first (so it's visible in Orders
/// even if the payment-link call subsequently fails), then request a Payment Link via the web
/// app's proxy, then either clear the cart and hand off a token for the status screen, or roll the
/// order back to `pending` on a KYC gate, or leave it as `awaiting_payment` on any other failure.
@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var line1 = ""
    @Published var line2 = ""
    @Published var city = ""
    @Published var region = ""
    @Published var postalCode = ""
    @Published var country = ""

    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var paymentLinkToken: String?

    private let ordersService: OrdersService
    private let payLinkGateway: PayLinkGateway
    private let cartStore: CartStore
    private let userId: String
    private let webOrderBaseURL: URL

    init(config: AppConfig, cartStore: CartStore, userId: String) {
        ordersService = OrdersService(config: config)
        payLinkGateway = PayLinkGateway(proxyBaseURL: config.payLinkProxyBaseURL, mudbaseBaseURL: config.baseURL)
        self.cartStore = cartStore
        self.userId = userId
        webOrderBaseURL = config.payLinkProxyBaseURL
    }

    var canSubmit: Bool {
        !isSubmitting
            && !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !line1.trimmingCharacters(in: .whitespaces).isEmpty
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
            && !region.trimmingCharacters(in: .whitespaces).isEmpty
            && !postalCode.trimmingCharacters(in: .whitespaces).isEmpty
            && !country.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func placeOrder() async {
        guard canSubmit, !cartStore.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let address = ShippingAddress(
            fullName: fullName,
            line1: line1,
            line2: line2.isEmpty ? nil : line2,
            city: city,
            region: region,
            postalCode: postalCode,
            country: country
        )
        let items = cartStore.items
        let subtotalCents = cartStore.subtotalCents

        let order: Order
        do {
            order = try await ordersService.create(userId: userId, items: items, subtotalCents: subtotalCents, shippingAddress: address)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
            return
        }

        let redirectUrl = webOrderBaseURL.appendingPathComponent("orders/\(order.id)").absoluteString
        let request = PayLinkGateway.CreateRequest(
            orderId: order.id,
            amount: Formatting.decimalAmountString(cents: subtotalCents),
            currency: "USDC",
            network: "POLYGON",
            redirectUrl: redirectUrl
        )

        switch await payLinkGateway.createPaymentLink(request) {
        case .success(let token):
            try? await ordersService.setPaymentLinkToken(orderId: order.id, token: token)
            await cartStore.clear()
            paymentLinkToken = token
        case .kycRequired(let message):
            try? await ordersService.setOrderStatus(orderId: order.id, status: .pending)
            errorMessage = message
        case .failure(let message):
            errorMessage = message
        }
    }
}
