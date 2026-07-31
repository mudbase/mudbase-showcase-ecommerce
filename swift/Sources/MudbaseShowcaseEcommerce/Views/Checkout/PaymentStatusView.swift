import SwiftUI

/// Mirrors `checkout/[token]/page.tsx` + `PaymentLinkPanel.tsx`: polls the public payment-link
/// endpoint until it reaches a terminal status.
struct PaymentStatusView: View {
    @StateObject private var viewModel: PaymentStatusViewModel

    init(config: AppConfig, token: String) {
        _viewModel = StateObject(wrappedValue: PaymentStatusViewModel(config: config, token: token))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage, viewModel.link == nil {
                    InlineErrorView(message: errorMessage)
                } else if let link = viewModel.link {
                    content(for: link)
                } else {
                    Text("Payment link not found.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Pay for your order")
        .inlineNavigationTitle()
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    @ViewBuilder
    private func content(for link: PublicPaymentLink) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Complete your payment")
                    .font(.headline)
                Spacer()
                statusBadge(for: link.status)
            }

            switch link.status {
            case .paid:
                Label("Payment received — thank you!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .expired, .cancelled:
                Label("This payment link is no longer active.", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .pending:
                Label("Waiting for payment — this screen updates automatically.", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, verticalSpacing: 8) {
                    GridRow {
                        Text("Amount").foregroundStyle(.secondary)
                        Text("\(link.amount ?? "—") \(link.currency)")
                    }
                    GridRow {
                        Text("Network").foregroundStyle(.secondary)
                        Text(link.network)
                    }
                    GridRow {
                        Text("Send to").foregroundStyle(.secondary)
                        Text(link.address)
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(3)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusBadge(for status: PaymentLinkStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .paid: return ("Paid", .green)
            case .expired: return ("Expired", .red)
            case .cancelled: return ("Cancelled", .red)
            case .pending: return ("Pending", .orange)
            }
        }()
        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
