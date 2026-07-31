import Foundation
import MudbaseSDK

/// Thin wrapper over `AuthenticationAPI` + `MultiRoleFeatureAPI`'s async/await calls. Kept
/// separate from `SessionStore` (which owns observable app state) so the actual network calls stay
/// unit-testable independent of SwiftUI/Observation.
struct AuthGateway {
    let projectId: String

    struct LoginResult {
        let accessToken: String
        let refreshToken: String
    }

    /// `POST /api/auth/local/signup/{role}` — always `role: "customer"` from this app's own
    /// register screen (self-signup never exposes a role picker; `seller` accounts are provisioned
    /// out-of-band, matching `web/README.md` "Provisioning"). Returns `Void` per the generated
    /// SDK's `registerWithRole` — the OpenAPI spec behind this endpoint doesn't give the generator
    /// a typed success body (it varies with `requireEmailVerification`), so this app follows
    /// registration with an explicit `login` call to obtain a real token. See README "Known
    /// limitations" for the same reason `agreedToTerms` (which the platform's validator requires
    /// for a *direct* signup call) has no home in the generated `RegisterWithRoleRequest` model.
    func registerCustomer(email: String, password: String, firstName: String, lastName: String) async throws(ErrorResponse) {
        try await MultiRoleFeatureAPI.registerWithRole(
            role: AppRole.customer.rawValue,
            registerWithRoleRequest: RegisterWithRoleRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                projectId: projectId
            )
        )
    }

    /// `POST /api/auth/local/login`.
    func login(email: String, password: String) async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.loginLocalUser(
            loginLocalUserRequest: LoginLocalUserRequest(email: email, password: password, projectId: projectId)
        )
        guard let token = response.token, let refreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInLoginResponse)
        }
        return LoginResult(accessToken: token, refreshToken: refreshToken)
    }

    /// `GET /api/auth/local/session` — the only endpoint that returns the project end-user's
    /// custom role (`customer`/`seller`), since `LoginLocalUser200ResponseUser` doesn't include it.
    func currentUser() async throws(ErrorResponse) -> AppUser {
        let response = try await AuthenticationAPI.getLocalSession(projectId: projectId)
        guard let userJSON = response.user, let user = AppUser(json: userJSON) else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.malformedSessionUser)
        }
        return user
    }

    /// `POST /api/auth/refresh` — rotates the refresh token on every use (platform-enforced,
    /// single-use); the caller is responsible for persisting the new pair.
    func refresh(refreshToken: String) async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.refreshToken(refreshTokenRequest: RefreshTokenRequest(refreshToken: refreshToken))
        guard let token = response.token, let newRefreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInLoginResponse)
        }
        return LoginResult(accessToken: token, refreshToken: newRefreshToken)
    }

    /// `POST /api/auth/local/logout` — best-effort; callers clear local state regardless of outcome.
    func logout() async throws(ErrorResponse) {
        _ = try await AuthenticationAPI.logoutLocalUser()
    }
}

enum MudbaseClientError: Error, Equatable {
    case missingTokenInLoginResponse
    case malformedSessionUser
}
