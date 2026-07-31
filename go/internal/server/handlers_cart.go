package server

import (
	"net/http"
	"strconv"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

// CartData is the /cart page's content payload.
type CartData struct {
	Base
	Items         []CartLineView
	IsEmpty       bool
	SubtotalLabel string
}

// currentCartItems returns the shopper's cart regardless of whether they're a guest (session
// cookie) or a real customer (server-side `carts` document) - mirrors
// web/src/hooks/useCart.ts's dual-source `items` memo.
func (a *App) currentCartItems(r *http.Request) (models.CartItems, error) {
	data := sessionFrom(r)
	if !data.IsCustomer() {
		return data.GuestCart(), nil
	}
	cart, err := a.carts.ServerCart(r.Context(), data.AccessToken(), data.UserID())
	if err != nil {
		return nil, err
	}
	if cart == nil {
		return nil, nil
	}
	return cart.Items(), nil
}

// saveCartItems persists items to whichever backing store the current session uses.
func (a *App) saveCartItems(w http.ResponseWriter, r *http.Request, items models.CartItems) error {
	data := sessionFrom(r)
	if data.IsCustomer() {
		_, err := a.carts.SaveServerCart(r.Context(), data.AccessToken(), data.UserID(), items)
		return err
	}
	if err := data.SetGuestCart(items); err != nil {
		return err
	}
	return data.Save(w, r)
}

// handleCartShow renders the cart page.
func (a *App) handleCartShow(w http.ResponseWriter, r *http.Request) {
	items, err := a.currentCartItems(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := CartData{
		Base:          a.baseViewWithCartCount(r, "Your cart", items.TotalQuantity()),
		Items:         newCartLineViews(items),
		IsEmpty:       len(items) == 0,
		SubtotalLabel: formatMoney(items.SubtotalCents(), items.Currency()),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	a.render(w, r, http.StatusOK, "cart.html", view)
}

const defaultAddQuantity = 1

// handleCartAdd adds a product to the cart. It re-fetches the product server-side (rather than
// trusting form fields for name/price) so a stale product page can never write a manipulated
// price into the cart.
func (a *App) handleCartAdd(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	productID := r.FormValue("productId")
	slug := r.FormValue("slug")
	returnPath := "/products/" + slug

	quantity, err := strconv.ParseInt(r.FormValue("quantity"), 10, 64)
	if err != nil || quantity < 1 {
		quantity = defaultAddQuantity
	}

	data := sessionFrom(r)
	product, err := a.catalog.ByID(r.Context(), data.AccessToken(), productID)
	if err != nil {
		redirectWithError(w, r, returnPath, "Something went wrong adding this to your cart. Please try again.")
		return
	}
	if product.OutOfStock() {
		redirectWithError(w, r, returnPath, "That item just sold out.")
		return
	}
	if quantity > product.Stock {
		quantity = product.Stock
	}

	items, err := a.currentCartItems(r)
	if err != nil {
		redirectWithError(w, r, returnPath, "Something went wrong adding this to your cart. Please try again.")
		return
	}

	next := items.WithAddedItem(models.CartItem{
		ProductID:  product.ID,
		Name:       product.Name,
		PriceCents: product.PriceCents,
		Currency:   product.Currency,
		ImageURL:   product.ImageURL,
	}, quantity)

	if err := a.saveCartItems(w, r, next); err != nil {
		redirectWithError(w, r, returnPath, "Something went wrong adding this to your cart. Please try again.")
		return
	}

	redirectWithSuccess(w, r, returnPath, "Added to cart.")
}

// handleCartUpdate adjusts one line's quantity by a relative delta (+1/-1 from the cart page's
// stepper buttons), mirroring web/src/components/cart/CartLineItems.tsx's updateQuantity calls.
func (a *App) handleCartUpdate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	productID := r.FormValue("productId")
	delta, err := strconv.ParseInt(r.FormValue("delta"), 10, 64)
	if err != nil {
		redirectWithError(w, r, "/cart", "Couldn't update your cart. Please try again.")
		return
	}

	items, err := a.currentCartItems(r)
	if err != nil {
		redirectWithError(w, r, "/cart", "Couldn't update your cart. Please try again.")
		return
	}

	var current int64
	for _, item := range items {
		if item.ProductID == productID {
			current = item.Quantity
		}
	}

	if err := a.saveCartItems(w, r, items.WithQuantity(productID, current+delta)); err != nil {
		redirectWithError(w, r, "/cart", "Couldn't update your cart. Please try again.")
		return
	}
	http.Redirect(w, r, "/cart", http.StatusSeeOther)
}

// handleCartRemove removes one line entirely.
func (a *App) handleCartRemove(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	productID := r.FormValue("productId")

	items, err := a.currentCartItems(r)
	if err != nil {
		redirectWithError(w, r, "/cart", "Couldn't update your cart. Please try again.")
		return
	}

	if err := a.saveCartItems(w, r, items.WithoutItem(productID)); err != nil {
		redirectWithError(w, r, "/cart", "Couldn't update your cart. Please try again.")
		return
	}
	http.Redirect(w, r, "/cart", http.StatusSeeOther)
}
