package server

import (
	"strings"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

// Base holds the fields every page's layout needs (header nav, flash banner). It is embedded in
// every page-specific data struct so templates can read `.IsSignedIn`, `.Flash`, etc. directly at
// the top level via Go's promoted-field rules.
type Base struct {
	Title        string
	IsSignedIn   bool
	IsSeller     bool
	FirstName    string
	CartCount    int64
	FlashError   string
	FlashSuccess string
}

// ProductView is a display-ready product: every derived value (gallery, discount, formatted
// price) is computed once here instead of in the template.
type ProductView struct {
	models.Product
	Images          []string
	DiscountPercent *int
	PriceLabel      string
	CompareAtLabel  string
	OutOfStock      bool
}

func newProductView(p models.Product) ProductView {
	return ProductView{
		Product:         p,
		Images:          p.Gallery(),
		DiscountPercent: p.DiscountPercent(),
		PriceLabel:      formatMoney(p.PriceCents, p.Currency),
		CompareAtLabel:  compareAtLabel(p),
		OutOfStock:      p.OutOfStock(),
	}
}

func compareAtLabel(p models.Product) string {
	if p.CompareAtPriceCents == nil {
		return ""
	}
	return formatMoney(*p.CompareAtPriceCents, p.Currency)
}

func newProductViews(products []models.Product) []ProductView {
	views := make([]ProductView, 0, len(products))
	for _, p := range products {
		views = append(views, newProductView(p))
	}
	return views
}

// CartLineView is a display-ready cart line item.
type CartLineView struct {
	models.CartItem
	LineTotalLabel string
	PriceLabel     string
}

func newCartLineViews(items models.CartItems) []CartLineView {
	views := make([]CartLineView, 0, len(items))
	for _, item := range items {
		views = append(views, CartLineView{
			CartItem:       item,
			LineTotalLabel: formatMoney(item.LineTotalCents(), item.Currency),
			PriceLabel:     formatMoney(item.PriceCents, item.Currency),
		})
	}
	return views
}

// OrderView is a display-ready order summary row (used in lists).
type OrderView struct {
	models.Order
	ShortID       string
	SubtotalLabel string
	CreatedLabel  string
	StatusLabel   string
	StatusVariant string
	NextStatus    models.OrderStatus
	HasNextStatus bool
	ShippingLabel string
}

func newOrderView(o models.Order) OrderView {
	next, hasNext := o.OrderStatus.NextStatus()
	shipping := o.ShippingName
	if shipping == "" {
		shipping = "Guest"
	}
	return OrderView{
		Order:         o,
		ShortID:       shortID(o.ID),
		SubtotalLabel: formatMoney(o.SubtotalCents, o.Currency),
		CreatedLabel:  formatDate(o.CreatedAt),
		StatusLabel:   o.OrderStatus.StatusLabel(),
		StatusVariant: o.OrderStatus.StatusVariant(),
		NextStatus:    next,
		HasNextStatus: hasNext,
		ShippingLabel: shipping,
	}
}

func newOrderViews(orders []models.Order) []OrderView {
	views := make([]OrderView, 0, len(orders))
	for _, o := range orders {
		views = append(views, newOrderView(o))
	}
	return views
}

// OrderItemView is a display-ready order line item.
type OrderItemView struct {
	models.OrderLineItem
	PriceLabel     string
	LineTotalLabel string
}

func newOrderItemViews(items []models.OrderLineItem, currency string) []OrderItemView {
	views := make([]OrderItemView, 0, len(items))
	for _, item := range items {
		views = append(views, OrderItemView{
			OrderLineItem:  item,
			PriceLabel:     formatMoney(item.PriceCents, currency),
			LineTotalLabel: formatMoney(item.LineTotalCents(), currency),
		})
	}
	return views
}

// TimelineStep is one step in the order-progress timeline.
type TimelineStep struct {
	Label string
	Done  bool
}

func newOrderTimeline(status models.OrderStatus) []TimelineStep {
	if status == models.OrderStatusCancelled {
		return nil
	}
	steps := []struct {
		status models.OrderStatus
		label  string
	}{
		{models.OrderStatusPending, "Placed"},
		{models.OrderStatusPaid, "Paid"},
		{models.OrderStatusShipped, "Shipped"},
		{models.OrderStatusDelivered, "Delivered"},
	}
	effective := status
	if status == models.OrderStatusAwaitingPayment {
		effective = models.OrderStatusPending
	}
	currentIndex := -1
	for i, s := range steps {
		if s.status == effective {
			currentIndex = i
		}
	}
	result := make([]TimelineStep, 0, len(steps))
	for i, s := range steps {
		result = append(result, TimelineStep{Label: s.label, Done: i <= currentIndex})
	}
	return result
}

func shortID(id string) string {
	tail := id
	if len(id) > 6 {
		tail = id[len(id)-6:]
	}
	return strings.ToUpper(tail)
}
