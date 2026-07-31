import SwiftUI

/// Mirrors `ProductCard.tsx`.
struct ProductCardView: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color.clear
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                if let discountPercent = product.discountPercent {
                    Text("\(discountPercent)% off")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }

            Text(product.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(Formatting.money(cents: product.priceCents, currency: product.currency))
                    .font(.subheadline.bold())
                if let compareAtPriceCents = product.compareAtPriceCents, product.discountPercent != nil {
                    Text(Formatting.money(cents: compareAtPriceCents, currency: product.currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }
            }

            if product.stock <= 0 {
                Text("Out of stock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
