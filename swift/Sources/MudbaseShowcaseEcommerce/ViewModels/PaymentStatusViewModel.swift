import Foundation

/// Mirrors `usePaymentLinkStatus.ts`: polls the public payment-link endpoint every 4s, continuing
/// through fetch errors, until the link reaches a terminal status (`paid`/`expired`/`cancelled`).
@MainActor
final class PaymentStatusViewModel: ObservableObject {
    @Published private(set) var link: PublicPaymentLink?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let gateway: PayLinkGateway
    private let token: String
    private let pollInterval: Duration
    private var pollTask: Task<Void, Never>?

    init(config: AppConfig, token: String, pollInterval: Duration = .seconds(4)) {
        gateway = PayLinkGateway(proxyBaseURL: config.payLinkProxyBaseURL, mudbaseBaseURL: config.baseURL)
        self.token = token
        self.pollInterval = pollInterval
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            let result = await gateway.fetchPaymentLinkStatus(token: token)
            if Task.isCancelled { return }

            switch result {
            case .ok(let fetchedLink):
                link = fetchedLink
                errorMessage = nil
                isLoading = false
                if fetchedLink.status != .pending { return }
            case .failure(let message):
                errorMessage = message
                isLoading = false
            }

            do {
                try await Task.sleep(for: pollInterval)
            } catch {
                return
            }
        }
    }
}
