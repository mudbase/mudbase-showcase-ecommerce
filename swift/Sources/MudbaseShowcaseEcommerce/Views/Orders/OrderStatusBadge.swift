import SwiftUI

/// Mirrors `OrderStatusBadge.tsx`.
struct OrderStatusBadge: View {
    let status: OrderStatus

    private var color: Color {
        switch status {
        case .delivered, .paid: return .green
        case .cancelled: return .red
        case .awaitingPayment, .pending: return .orange
        case .shipped: return .blue
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
