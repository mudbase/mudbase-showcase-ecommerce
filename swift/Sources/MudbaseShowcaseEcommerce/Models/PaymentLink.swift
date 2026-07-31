import Foundation

enum PaymentLinkStatus: String, Sendable, Equatable, Codable {
    case pending
    case paid
    case expired
    case cancelled
}

/// The public, unauthenticated read shape returned by both the pay-link proxy's success response
/// and `GET /api/payment-links/:token` — mirrors `PublicPaymentLink` in
/// `web/src/lib/mudbase-server.ts`.
struct PublicPaymentLink: Sendable, Equatable, Codable {
    let token: String
    let amount: String?
    let currency: String
    let network: String
    let address: String
    let description: String?
    let redirectUrl: String?
    let status: PaymentLinkStatus
    let expiresAt: String?
}
