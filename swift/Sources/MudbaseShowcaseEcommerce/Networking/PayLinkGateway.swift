import Foundation

/// Calls the already-deployed web app's `/api/checkout/pay-link` Route Handler and the public,
/// unauthenticated `GET /api/payment-links/:token` read. These are plain `URLSession` calls, not
/// generated SDK calls: creating a Payment Link needs an org owner/admin bearer token that must
/// never be embedded in a mobile app, so this app delegates creation to the web app's server-side
/// proxy exactly as instructed — see README "Payments".
struct PayLinkGateway {
    let proxyBaseURL: URL
    let mudbaseBaseURL: URL
    private let session: URLSession

    init(proxyBaseURL: URL, mudbaseBaseURL: URL, session: URLSession = .shared) {
        self.proxyBaseURL = proxyBaseURL
        self.mudbaseBaseURL = mudbaseBaseURL
        self.session = session
    }

    struct CreateRequest: Encodable {
        let orderId: String
        let amount: String
        let currency: String
        let network: String
        let redirectUrl: String
    }

    private struct CreateSuccessBody: Decodable {
        struct LinkToken: Decodable { let token: String }
        let link: LinkToken
    }

    private struct CreateErrorBody: Decodable {
        let error: String?
        let reason: String?
    }

    enum CreateResult {
        case success(token: String)
        case kycRequired(message: String)
        case failure(message: String)
    }

    /// `POST {proxyBaseURL}/api/checkout/pay-link` — mirrors `checkout/page.tsx`'s `placeOrder`.
    func createPaymentLink(_ request: CreateRequest) async -> CreateResult {
        let url = proxyBaseURL.appendingPathComponent("api/checkout/pay-link")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return .failure(message: "Couldn't start payment. Please try again.")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            return .failure(message: "Couldn't reach the payment service. Please check your connection and try again.")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(message: "Couldn't start payment. Please try again.")
        }

        if httpResponse.statusCode == 201, let body = try? JSONDecoder().decode(CreateSuccessBody.self, from: data) {
            return .success(token: body.link.token)
        }

        let errorBody = try? JSONDecoder().decode(CreateErrorBody.self, from: data)
        if httpResponse.statusCode == 403 && errorBody?.reason == "kyc_required" {
            return .kycRequired(message: errorBody?.error ?? "This store's payments are still pending identity verification.")
        }
        return .failure(message: errorBody?.error ?? "Couldn't start payment. Please try again.")
    }

    enum StatusResult {
        case ok(PublicPaymentLink)
        case failure(message: String)
    }

    private struct StatusSuccessBody: Decodable { let link: PublicPaymentLink }
    private struct StatusErrorBody: Decodable { let error: String? }

    /// `GET {mudbaseBaseURL}/api/payment-links/:token` — public, no auth. Mirrors
    /// `usePaymentLinkStatus`'s single-fetch `fetchOnce`; the caller drives the polling loop.
    func fetchPaymentLinkStatus(token: String) async -> StatusResult {
        let url = mudbaseBaseURL.appendingPathComponent("api/payment-links/\(token)")
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(message: "Couldn't check payment status.")
            }
            if httpResponse.statusCode == 200, let body = try? JSONDecoder().decode(StatusSuccessBody.self, from: data) {
                return .ok(body.link)
            }
            let errorBody = try? JSONDecoder().decode(StatusErrorBody.self, from: data)
            return .failure(message: errorBody?.error ?? "Payment link not available")
        } catch {
            return .failure(message: "Couldn't check payment status.")
        }
    }
}
