package models

// CartItem is one entry in a cart's JSON-encoded itemsJson array, or in the guest cart stored in
// the session cookie before the shopper has a real customer account.
type CartItem struct {
	ProductID  string `json:"productId"`
	Name       string `json:"name"`
	PriceCents int64  `json:"priceCents"`
	Currency   string `json:"currency"`
	ImageURL   string `json:"imageUrl,omitempty"`
	Quantity   int64  `json:"quantity"`
}

// LineTotalCents returns quantity * priceCents for this cart line.
func (c CartItem) LineTotalCents() int64 {
	return c.PriceCents * c.Quantity
}

// Cart mirrors the `carts` Mudbase collection schema: one document per customer, upserted
// read-then-create-or-update since Mudbase collections have no native upsert endpoint.
type Cart struct {
	ID        string `json:"_id"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
	UserID    string `json:"userId"`
	ItemsJSON string `json:"itemsJson"`
}

// Items decodes ItemsJSON into a slice of cart line items.
func (c Cart) Items() CartItems {
	return ParseJSONField[CartItems](c.ItemsJSON, nil)
}

// CartItems is a plain slice helper shared by the server-cart and guest-cart code paths so both
// can add/update/remove/merge with identical logic (mirrors web/src/hooks/useCart.ts).
type CartItems []CartItem

// SubtotalCents sums priceCents * quantity across every line.
func (items CartItems) SubtotalCents() int64 {
	var total int64
	for _, item := range items {
		total += item.LineTotalCents()
	}
	return total
}

// TotalQuantity sums the quantity of every line, used for the header cart-count badge.
func (items CartItems) TotalQuantity() int64 {
	var total int64
	for _, item := range items {
		total += item.Quantity
	}
	return total
}

// Currency returns the currency of the first line item, defaulting to USD for an empty cart.
func (items CartItems) Currency() string {
	if len(items) == 0 {
		return "USD"
	}
	return items[0].Currency
}

// WithAddedItem returns a new slice with quantity added to productId's line (creating it if
// absent), leaving the receiver untouched.
func (items CartItems) WithAddedItem(item CartItem, quantity int64) CartItems {
	next := make(CartItems, len(items))
	copy(next, items)
	for i, existing := range next {
		if existing.ProductID == item.ProductID {
			next[i].Quantity += quantity
			return next
		}
	}
	added := item
	added.Quantity = quantity
	return append(next, added)
}

// WithQuantity returns a new slice with productId's quantity set to quantity, removing the line
// entirely when quantity <= 0.
func (items CartItems) WithQuantity(productID string, quantity int64) CartItems {
	next := make(CartItems, 0, len(items))
	for _, existing := range items {
		if existing.ProductID != productID {
			next = append(next, existing)
			continue
		}
		if quantity > 0 {
			updated := existing
			updated.Quantity = quantity
			next = append(next, updated)
		}
	}
	return next
}

// WithoutItem returns a new slice with productId's line removed.
func (items CartItems) WithoutItem(productID string) CartItems {
	return items.WithQuantity(productID, 0)
}

// MergedWith returns a new slice combining items with other, summing quantities for any
// productId present in both (mirrors migrateGuestCartToServer's merge-on-sign-in logic).
func (items CartItems) MergedWith(other CartItems) CartItems {
	next := make(CartItems, len(items))
	copy(next, items)
	for _, o := range other {
		next = next.WithAddedItem(CartItem{
			ProductID:  o.ProductID,
			Name:       o.Name,
			PriceCents: o.PriceCents,
			Currency:   o.Currency,
			ImageURL:   o.ImageURL,
		}, o.Quantity)
	}
	return next
}
