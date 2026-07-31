import SwiftUI

/// Mirrors one `<li>` in `CartLineItems.tsx`.
struct CartLineItemView: View {
    let item: CartItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 56, height: 56)
                .overlay {
                    if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.clear
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(Formatting.money(cents: item.priceCents, currency: item.currency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                }
                Text("\(item.quantity)")
                    .frame(minWidth: 20)
                Button(action: onIncrement) {
                    Image(systemName: "plus")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(Formatting.money(cents: item.lineTotalCents, currency: item.currency))
                .font(.subheadline.weight(.medium))
                .frame(width: 70, alignment: .trailing)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}
