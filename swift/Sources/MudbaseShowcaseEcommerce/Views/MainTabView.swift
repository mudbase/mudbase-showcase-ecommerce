import SwiftUI

/// The Seller tab only appears for a signed-in `seller` — the same effective gate as the web
/// app's `SellerGuard` (`customRole === "seller"`), just applied at the tab level instead of a
/// redirect-on-mismatch.
struct MainTabView: View {
    let user: AppUser
    let config: AppConfig

    var body: some View {
        TabView {
            NavigationStack {
                CatalogView(config: config)
            }
            .tabItem { Label("Shop", systemImage: "bag") }

            NavigationStack {
                CartView(config: config)
            }
            .tabItem { Label("Cart", systemImage: "cart") }

            NavigationStack {
                OrdersListView(config: config, userId: user.id)
            }
            .tabItem { Label("Orders", systemImage: "shippingbox") }

            if user.isSeller {
                NavigationStack {
                    SellerDashboardView(config: config, sellerId: user.id)
                }
                .tabItem { Label("Seller", systemImage: "storefront") }
            }

            NavigationStack {
                AccountView(user: user)
            }
            .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
