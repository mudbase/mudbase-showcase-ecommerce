import Foundation

/// `navigationDestination(for:)` registers one destination builder per *type* within a given
/// `NavigationStack`. Two different navigation targets that both happened to push a bare `String`
/// (an order id and a payment-link token) would collide if they ever appear in the same stack —
/// the Orders tab's stack does exactly that (`OrdersListView` pushes an order id, `OrderDetailView`
/// then pushes a payment token). These small wrapper types give each navigation edge its own type
/// so the two destinations can never be confused with one another.
struct OrderReference: Hashable {
    let orderId: String
}

struct PaymentTokenReference: Hashable {
    let token: String
}
