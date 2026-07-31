import SwiftUI

/// Mirrors `OrderTimeline.tsx`.
struct OrderTimelineView: View {
    let status: OrderStatus

    private struct Step {
        let status: OrderStatus
        let label: String
    }

    private static let steps: [Step] = [
        Step(status: .pending, label: "Placed"),
        Step(status: .paid, label: "Paid"),
        Step(status: .shipped, label: "Shipped"),
        Step(status: .delivered, label: "Delivered"),
    ]

    private var effectiveStatus: OrderStatus {
        status == .awaitingPayment ? .pending : status
    }

    private var currentIndex: Int {
        Self.steps.firstIndex { $0.status == effectiveStatus } ?? 0
    }

    var body: some View {
        if status == .cancelled {
            Text("This order was cancelled.")
                .font(.footnote)
                .foregroundStyle(.red)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                    let done = index <= currentIndex
                    HStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(done ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                                .background(Circle().fill(done ? Color.accentColor : Color.clear))
                                .frame(width: 24, height: 24)
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(step.label)
                            .font(.caption)
                            .fontWeight(done ? .semibold : .regular)
                            .foregroundStyle(done ? Color.primary : Color.secondary)
                    }
                    if index < Self.steps.count - 1 {
                        Rectangle()
                            .fill(done ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}
