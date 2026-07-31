package models

// OrderStatus mirrors the `orders` collection's orderStatus enum.
type OrderStatus string

// OrderPaymentStatus mirrors the `orders` collection's paymentStatus enum.
type OrderPaymentStatus string

const (
	OrderStatusPending         OrderStatus = "pending"
	OrderStatusAwaitingPayment OrderStatus = "awaiting_payment"
	OrderStatusPaid            OrderStatus = "paid"
	OrderStatusShipped         OrderStatus = "shipped"
	OrderStatusDelivered       OrderStatus = "delivered"
	OrderStatusCancelled       OrderStatus = "cancelled"

	OrderPaymentStatusUnpaid    OrderPaymentStatus = "unpaid"
	OrderPaymentStatusPaid      OrderPaymentStatus = "paid"
	OrderPaymentStatusExpired   OrderPaymentStatus = "expired"
	OrderPaymentStatusCancelled OrderPaymentStatus = "cancelled"
)

// OrderLineItem is one entry in an order's JSON-encoded itemsJson array.
type OrderLineItem struct {
	ProductID  string `json:"productId"`
	Name       string `json:"name"`
	PriceCents int64  `json:"priceCents"`
	Quantity   int64  `json:"quantity"`
}

// LineTotalCents returns quantity * priceCents for this line item.
func (li OrderLineItem) LineTotalCents() int64 {
	return li.PriceCents * li.Quantity
}

// ShippingAddress is the JSON-encoded shape stored in Order.ShippingAddressJSON.
type ShippingAddress struct {
	FullName   string `json:"fullName"`
	Line1      string `json:"line1"`
	Line2      string `json:"line2,omitempty"`
	City       string `json:"city"`
	Region     string `json:"region"`
	PostalCode string `json:"postalCode"`
	Country    string `json:"country"`
}

// Order mirrors the `orders` Mudbase collection schema. The status field is named "orderStatus",
// not "status" - Mudbase's server-side role-assignment guard treats a literal "status" key on ANY
// collection write as a protected role field and rejects it for every project end-user (sellers
// included), regardless of that collection's own permission rules. Real platform constraint, see
// web/README.md "Known limitations".
type Order struct {
	ID                  string             `json:"_id"`
	CreatedAt           string             `json:"createdAt"`
	UpdatedAt           string             `json:"updatedAt"`
	UserID              string             `json:"userId"`
	ItemsJSON           string             `json:"itemsJson"`
	SubtotalCents       int64              `json:"subtotalCents"`
	Currency            string             `json:"currency"`
	OrderStatus         OrderStatus        `json:"orderStatus"`
	ShippingName        string             `json:"shippingName"`
	ShippingAddressJSON string             `json:"shippingAddressJson"`
	PaymentLinkToken    string             `json:"paymentLinkToken"`
	PaymentStatus       OrderPaymentStatus `json:"paymentStatus"`
}

// Items decodes ItemsJSON into a slice of line items.
func (o Order) Items() []OrderLineItem {
	return ParseJSONField[[]OrderLineItem](o.ItemsJSON, nil)
}

// ShippingAddress decodes ShippingAddressJSON, returning nil when absent or malformed.
func (o Order) Address() *ShippingAddress {
	return ParseJSONField[*ShippingAddress](o.ShippingAddressJSON, nil)
}

// StatusLabel returns the human-readable label for the seller/customer-facing status badge.
func (s OrderStatus) StatusLabel() string {
	switch s {
	case OrderStatusPending:
		return "Pending"
	case OrderStatusAwaitingPayment:
		return "Awaiting payment"
	case OrderStatusPaid:
		return "Paid"
	case OrderStatusShipped:
		return "Shipped"
	case OrderStatusDelivered:
		return "Delivered"
	case OrderStatusCancelled:
		return "Cancelled"
	default:
		return string(s)
	}
}

// StatusVariant maps a status to a badge color variant name used by the templates.
func (s OrderStatus) StatusVariant() string {
	switch s {
	case OrderStatusDelivered, OrderStatusPaid:
		return "success"
	case OrderStatusCancelled:
		return "destructive"
	case OrderStatusAwaitingPayment, OrderStatusPending:
		return "warning"
	default:
		return "secondary"
	}
}

// NextStatus returns the seller fulfillment queue's next status button target, and whether one
// exists (mirrors web/src/components/seller/SellerOrderQueue.tsx's NEXT_STATUS map).
func (s OrderStatus) NextStatus() (OrderStatus, bool) {
	switch s {
	case OrderStatusPaid:
		return OrderStatusShipped, true
	case OrderStatusShipped:
		return OrderStatusDelivered, true
	default:
		return "", false
	}
}
