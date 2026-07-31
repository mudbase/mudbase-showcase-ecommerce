import SwiftUI

/// App entry point. Configures the shared `MudbaseSDKAPIConfiguration` once at launch (see
/// `MudbaseSDKBootstrap`) and owns the two app-wide observable stores (`SessionStore`, `CartStore`)
/// as `@StateObject`s so they survive view identity churn across the whole app lifetime.
@main
struct MudbaseShowcaseEcommerceApp: App {
    private let configResult: Result<AppConfig, ConfigurationError>
    @StateObject private var sessionStore: SessionStore
    @StateObject private var cartStore: CartStore

    init() {
        let result = AppConfig.load()
        configResult = result
        switch result {
        case .success(let config):
            MudbaseSDKBootstrap.configure(baseURL: config.baseURL)
            _sessionStore = StateObject(wrappedValue: SessionStore(config: config))
            _cartStore = StateObject(wrappedValue: CartStore(config: config))
        case .failure:
            // Placeholder config — never used, since `body` renders `ConfigurationRequiredView`
            // instead of `RootView` in this case. A concrete (if inert) value keeps the
            // `@StateObject` properties non-optional, which keeps every downstream view's
            // `@EnvironmentObject` usage non-optional too.
            // `URL(fileURLWithPath:)` is non-failable, so this never needs a force-unwrap even
            // though the URL string itself is a valid constant — this value is inert regardless.
            let placeholder = AppConfig(
                projectId: "",
                baseURL: URL(string: "https://cloud.mudbase.dev") ?? URL(fileURLWithPath: "/"),
                productsCollectionId: "",
                ordersCollectionId: "",
                cartsCollectionId: "",
                payLinkProxyBaseURL: URL(string: "https://mudbase-showcase-ecommerce.vercel.app") ?? URL(fileURLWithPath: "/")
            )
            _sessionStore = StateObject(wrappedValue: SessionStore(config: placeholder))
            _cartStore = StateObject(wrappedValue: CartStore(config: placeholder))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch configResult {
            case .success(let config):
                RootView(config: config)
                    .environmentObject(sessionStore)
                    .environmentObject(cartStore)
                    .environment(\.appConfig, config)
            case .failure(let error):
                ConfigurationRequiredView(error: error)
            }
        }
    }
}
