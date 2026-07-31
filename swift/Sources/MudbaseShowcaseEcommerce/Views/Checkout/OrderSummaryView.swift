import SwiftUI

/// Mirrors `OrderSummary.tsx`.
struct OrderSummaryView: View {
    let items: [CartItem]
    let subtotalCents: Int

    private var currency: String { items.first?.currency ?? "USD" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order summary")
                .font(.subheadline.weight(.semibold))

            ForEach(items) { item in
                HStack {
                    Text("\(item.name) × \(item.quantity)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Formatting.money(cents: item.lineTotalCents, currency: item.currency))
                        .font(.footnote)
                }
            }

            Divider()

            HStack {
                Text("Total").font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formatting.money(cents: subtotalCents, currency: currency))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
