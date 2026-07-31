import SwiftUI

/// Mirrors `SellerOrderQueue.tsx` — every order, with a one-tap forward status transition.
struct SellerOrderQueueView: View {
    @StateObject private var viewModel: SellerOrderQueueViewModel

    init(config: AppConfig) {
        _viewModel = StateObject(wrappedValue: SellerOrderQueueViewModel(config: config))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if viewModel.orders.isEmpty {
                EmptyStateView(message: "No orders yet — they'll appear here the instant one comes in.")
            } else {
                List(viewModel.orders) { order in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Order #\(order.shortId)")
                                .font(.subheadline.weight(.medium))
                            Text((order.shippingName ?? "Guest") + (order.createdAt.map { " · \(Formatting.date($0))" } ?? ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Formatting.money(cents: order.subtotalCents, currency: order.currency))
                            .font(.footnote)
                        OrderStatusBadge(status: order.orderStatus)
                        if let next = order.orderStatus.nextFulfillmentStatus {
                            Button("Mark \(next.label)") {
                                Task { await viewModel.advance(order) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.updatingOrderId == order.id)
                        }
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
