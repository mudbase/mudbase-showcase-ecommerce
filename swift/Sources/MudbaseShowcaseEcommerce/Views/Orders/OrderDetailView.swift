import SwiftUI

/// Mirrors `orders/[id]/page.tsx` (`OrderTimeline.tsx` + `OrderItemsTable.tsx` inlined).
struct OrderDetailView: View {
    @StateObject private var viewModel: OrderDetailViewModel
    private let config: AppConfig

    init(config: AppConfig, orderId: String) {
        self.config = config
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(config: config, orderId: orderId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) { Task { await viewModel.load() } }
            } else if let order = viewModel.order {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Order #\(order.shortId)")
                                    .font(.title3.bold())
                                if let createdAt = order.createdAt {
                                    Text(Formatting.date(createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            OrderStatusBadge(status: order.orderStatus)
                        }

                        OrderTimelineView(status: order.orderStatus)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Items").font(.subheadline.weight(.semibold))
                            ForEach(order.items) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                        Text("Qty \(item.quantity) × \(Formatting.money(cents: item.priceCents, currency: order.currency))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(Formatting.money(cents: item.lineTotalCents, currency: order.currency))
                                }
                            }
                            HStack {
                                Text("Total").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Formatting.money(cents: order.subtotalCents, currency: order.currency))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        if let address = order.shippingAddress {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shipping to").font(.subheadline.weight(.semibold))
                                Text(address.fullName)
                                Text(address.line1 + (address.line2.map { ", \($0)" } ?? ""))
                                Text("\(address.city), \(address.region) \(address.postalCode)")
                                Text(address.country)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }

                        if let token = order.paymentLinkToken, order.paymentStatus != .paid {
                            NavigationLink("Complete payment", value: PaymentTokenReference(token: token))
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            } else {
                EmptyStateView(message: "This order couldn't be found.")
            }
        }
        .navigationTitle("Order")
        .inlineNavigationTitle()
        .task { await viewModel.load() }
        .navigationDestination(for: PaymentTokenReference.self) { reference in
            PaymentStatusView(config: config, token: reference.token)
        }
    }
}
