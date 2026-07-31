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

    struct RegisterResult {
        /// True when the project requires email verification before a session is issued — in
        /// that case `session`/`user` are both `nil` and the caller shows a "check your email"
        /// message instead.
        let requiresVerification: Bool
        let session: LoginResult?
        let user: AppUser?
    }

    /// `POST /api/auth/local/signup/{role}` — always `role: "customer"` from this app's own
    /// register screen (self-signup never exposes a role picker; `seller` accounts are provisioned
    /// out-of-band, matching `web/README.md` "Provisioning"). `agreedToTerms` is enforced
    /// client-side by the register screen's own validation, and is now also transmitted to the
    /// server: the regenerated SDK's `RegisterWithRoleRequest` gained this field (the platform's
    /// registration validator requires it for a *direct* signup call), which previously had no
    /// home in the generated model at all.
    ///
    /// `registerWithRole` also now returns a typed `RegisterWithRole201Response` (previously
    /// `Void` — the OpenAPI spec didn't give the generator a single success body because the shape
    /// varies with `requireEmailVerification`). When verification isn't required, that response
    /// carries the token pair *and* the user (including `customRole`) directly, so this no longer
    /// needs a follow-up `login` + `getLocalSession` round trip to obtain a real session — see
    /// `SessionStore.register`.
    func registerCustomer(email: String, password: String, firstName: String, lastName: String, agreedToTerms: Bool) async throws(ErrorResponse) -> RegisterResult {
        let response = try await MultiRoleFeatureAPI.registerWithRole(
            role: AppRole.customer.rawValue,
            registerWithRoleRequest: RegisterWithRoleRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                projectId: projectId,
                agreedToTerms: agreedToTerms
            )
        )
        if response.requireVerification == true {
            return RegisterResult(requiresVerification: true, session: nil, user: nil)
        }
        guard let token = response.token,
              let refreshToken = response.refreshToken,
              let responseUser = response.user,
              let user = AppUser(registered: responseUser)
        else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInLoginResponse)
        }
        return RegisterResult(requiresVerification: false, session: LoginResult(accessToken: token, refreshToken: refreshToken), user: user)
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
