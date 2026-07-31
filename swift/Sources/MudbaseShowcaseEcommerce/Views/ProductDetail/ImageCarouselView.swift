import SwiftUI

/// Mirrors `ImageCarousel.tsx` — a swipeable, manually-advanceable gallery (main image + extra
/// `galleryJson` photos).
struct ImageCarouselView: View {
    let imageURLs: [String]

    var body: some View {
        if imageURLs.isEmpty {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.12))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        } else {
            TabView {
                ForEach(imageURLs, id: \.self) { urlString in
                    AsyncImage(url: URL(string: urlString)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Color.secondary.opacity(0.12)
                        }
                    }
                }
            }
            .pagedTabViewStyle()
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
