import SwiftUI

/// Mirrors `orders/page.tsx` + `OrderList.tsx`.
struct OrdersListView: View {
    @StateObject private var viewModel: OrdersListViewModel
    private let config: AppConfig

    init(config: AppConfig, userId: String) {
        self.config = config
        _viewModel = StateObject(wrappedValue: OrdersListViewModel(config: config, userId: userId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if viewModel.orders.isEmpty {
                EmptyStateView(message: "No orders yet.")
            } else {
                List(viewModel.orders) { order in
                    NavigationLink(value: OrderReference(orderId: order.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Order #\(order.shortId)")
                                    .font(.subheadline.weight(.medium))
                                if let createdAt = order.createdAt {
                                    Text(Formatting.date(createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(Formatting.money(cents: order.subtotalCents, currency: order.currency))
                                .font(.subheadline)
                            OrderStatusBadge(status: order.orderStatus)
                        }
                    }
                }
            }
        }
        .navigationTitle("Your orders")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: OrderReference.self) { reference in
            OrderDetailView(config: config, orderId: reference.orderId)
        }
    }
}
