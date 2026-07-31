import Foundation
import MudbaseSDK

/// Owns the app's auth state end to end: bootstrap-from-Keychain at launch, login, register
/// (customer self-signup only — see README "Provisioning"), logout, and one-shot refresh-on-401.
/// The SwiftUI equivalent of `web/src/lib/mudbase-provider.tsx` + `web/src/hooks/useAuth.ts`
/// combined, minus the anonymous-guest session (this app requires login before browsing — see the
/// build brief's own instruction on that point).
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var isBootstrapping = true

    private let authGateway: AuthGateway
    private let tokenStore: KeychainTokenStore

    init(config: AppConfig, tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.authGateway = AuthGateway(projectId: config.projectId)
        self.tokenStore = tokenStore
    }

    var isSignedIn: Bool { user != nil }

    /// Called once at app launch. Restores a stored token, validating it against the session
    /// endpoint; on a 401 (expired access token) attempts exactly one refresh before giving up.
    func bootstrap() async {
        defer { isBootstrapping = false }
        guard let stored = tokenStore.load() else { return }

        MudbaseSDKBootstrap.setAccessToken(stored.accessToken)
        do {
            user = try await authGateway.currentUser()
            return
        } catch {
            // Fall through to a single refresh attempt below.
        }

        do {
            let refreshed = try await authGateway.refresh(refreshToken: stored.refreshToken)
            tokenStore.save(.init(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken))
            MudbaseSDKBootstrap.setAccessToken(refreshed.accessToken)
            user = try await authGateway.currentUser()
        } catch {
            tokenStore.clear()
            MudbaseSDKBootstrap.clearAccessToken()
            user = nil
        }
    }

    func login(email: String, password: String) async -> Result<Void, MudbaseAPIError.DisplayableError> {
        do {
            let result = try await authGateway.login(email: email, password: password)
            tokenStore.save(.init(accessToken: result.accessToken, refreshToken: result.refreshToken))
            MudbaseSDKBootstrap.setAccessToken(result.accessToken)
            user = try await authGateway.currentUser()
            return .success(())
        } catch {
            return .failure(MudbaseAPIError.map(error))
        }
    }

    enum RegisterOutcome: Equatable {
        case signedIn
        case verificationRequired(message: String)
        case failure(message: String)
    }

    /// Role is always `customer` — self-signup never exposes a role picker (`seller` accounts are
    /// provisioned out-of-band). See `AuthGateway.registerCustomer` for why this follows up with a
    /// real login call instead of trusting a token from the signup response itself.
    func register(email: String, password: String, firstName: String, lastName: String) async -> RegisterOutcome {
        do {
            try await authGateway.registerCustomer(email: email, password: password, firstName: firstName, lastName: lastName)
        } catch {
            return .failure(message: MudbaseAPIError.map(error).message)
        }

        let loginResult = await login(email: email, password: password)
        switch loginResult {
        case .success:
            return .signedIn
        case .failure(let displayable):
            if displayable.code == "EMAIL_VERIFICATION_REQUIRED" {
                return .verificationRequired(message: "Account created — check your email to verify it, then sign in.")
            }
            return .failure(message: displayable.message)
        }
    }

    func logout() async {
        _ = try? await authGateway.logout()
        tokenStore.clear()
        MudbaseSDKBootstrap.clearAccessToken()
        user = nil
    }
}
