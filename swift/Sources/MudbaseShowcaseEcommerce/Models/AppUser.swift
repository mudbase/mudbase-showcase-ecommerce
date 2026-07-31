import Foundation
import MudbaseSDK

enum AppRole: String, Sendable, Equatable {
    case customer
    case seller
}

/// Project end-user, as returned by `GET /api/auth/local/session`. The generated SDK types that
/// endpoint's `user` field as a raw `JSONValue` (`GetLocalSession200Response.user`) rather than a
/// fixed struct — unlike org/platform users (`Models/User.swift` in the SDK, which only has
/// `owner`/`admin`/`member`/`viewer` roles), project end-users carry whatever custom roles the
/// project's Multi-Role feature defines (`customer`/`seller` here), so the SDK can't model that
/// shape ahead of time. This type is this app's own typed read of that JSON.
struct AppUser: Sendable, Equatable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: AppRole?
    let emailVerified: Bool

    var displayName: String { "\(firstName) \(lastName)" }
    var isSeller: Bool { role == .seller }

    init?(json: JSONValue) {
        guard let dict = json.dictionaryValue,
              let id = dict["_id"]?.stringValue ?? dict["id"]?.stringValue,
              let email = dict["email"]?.stringValue
        else {
            return nil
        }
        self.id = id
        self.email = email
        self.firstName = dict["firstName"]?.stringValue ?? ""
        self.lastName = dict["lastName"]?.stringValue ?? ""
        self.emailVerified = dict["emailVerified"]?.boolValue ?? false
        self.role = (dict["customRole"]?.stringValue).flatMap(AppRole.init(rawValue:))
    }
}
