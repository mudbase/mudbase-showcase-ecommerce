import SwiftUI

/// Mirrors `CategoryFilter.tsx`.
struct CategoryFilterView: View {
    let categories: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "All", isSelected: selected == nil) { selected = nil }
                ForEach(categories, id: \.self) { category in
                    pill(title: category, isSelected: selected == category) { selected = category }
                }
            }
        }
    }

    private func pill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
