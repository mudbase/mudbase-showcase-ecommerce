import Foundation

enum Formatting {
    static func money(cents: Int, currency: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "en_US")
        let amount = Double(cents) / 100
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, currency)
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }

    static func slugify(_ value: String) -> String {
        let lowered = value.lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> Character in
            (CharacterSet.alphanumerics.contains(scalar)) ? Character(scalar) : "-"
        }
        var collapsed = ""
        var lastWasDash = false
        for character in mapped {
            if character == "-" {
                if !lastWasDash { collapsed.append(character) }
                lastWasDash = true
            } else {
                collapsed.append(character)
                lastWasDash = false
            }
        }
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Returns a whole-number discount percentage, or nil when there is no active discount.
    /// Mirrors `discountPercent()` in `web/src/lib/utils.ts`.
    static func discountPercent(priceCents: Int, compareAtPriceCents: Int?) -> Int? {
        guard let compareAtPriceCents, compareAtPriceCents > priceCents else { return nil }
        let ratio = 1.0 - (Double(priceCents) / Double(compareAtPriceCents))
        return Int((ratio * 100).rounded())
    }

    /// `(cents / 100)` formatted with exactly two decimals — the decimal-string amount the
    /// Payment Link proxy expects (`amount: "12.34"`), matching the web checkout page.
    static func decimalAmountString(cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
    }
}
