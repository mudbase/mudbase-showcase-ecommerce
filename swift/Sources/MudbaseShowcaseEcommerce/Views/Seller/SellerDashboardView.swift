import SwiftUI

/// Mirrors `seller/page.tsx` — the Seller tab is only shown to a signed-in `seller` (gated in
/// `MainTabView`), the same effective gate as the web app's `SellerGuard`.
struct SellerDashboardView: View {
    private let config: AppConfig
    private let sellerId: String

    init(config: AppConfig, sellerId: String) {
        self.config = config
        self.sellerId = sellerId
    }

    var body: some View {
        List {
            Section {
                NavigationLink("Order queue") {
                    SellerOrderQueueView(config: config)
                        .navigationTitle("Orders")
                }
            } header: {
                Text("Fulfillment")
            } footer: {
                Text("Every order across the store, oldest first.")
            }

            Section {
                NavigationLink("Manage products") {
                    SellerProductListView(config: config, sellerId: sellerId)
                        .navigationTitle("Products")
                }
            } header: {
                Text("Catalog")
            } footer: {
                Text("Create, edit, hide, or delete products.")
            }
        }
        .navigationTitle("Seller")
    }
}
