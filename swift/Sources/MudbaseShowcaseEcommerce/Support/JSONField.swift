import Foundation

/// Mudbase Collection fields have a fixed type enum (string, number, boolean, date, email, url,
/// enum, reference) with no native array/object type. Anything shaped like a list or a nested
/// record (order line items, a shipping address, extra product images) is stored as a JSON string
/// in a `string` field and parsed at the edges — a real, documented constraint of the platform's
/// Collections feature, mirroring `web/src/lib/json-field.ts` exactly.
enum JSONField {
    static func parse<T: Decodable>(_ value: String?, as type: T.Type, fallback: T) -> T {
        guard let value, let data = value.data(using: .utf8) else { return fallback }
        let decoder = JSONDecoder()
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    static func stringify(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value), let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
