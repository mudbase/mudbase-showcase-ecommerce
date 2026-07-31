package server

import (
	"errors"
	"fmt"
	"net/http"
	"net/mail"
	"net/url"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/store"
)

// checkoutCurrency/checkoutNetwork are the fixed payment-link parameters this demo storefront
// uses, matching web/src/app/checkout/page.tsx's placeOrder() exactly.
const (
	checkoutCurrency = "USDC"
	checkoutNetwork  = "POLYGON"
)

// CheckoutData is the /checkout page's content payload.
type CheckoutData struct {
	Base
	Items         []CartLineView
	SubtotalLabel string
	IsEmpty       bool
	IsCustomer    bool
	AuthMode      string
}

func checkoutRedirect(w http.ResponseWriter, r *http.Request, authMode, errorMsg string) {
	q := url.Values{}
	if authMode != "" {
		q.Set("authMode", authMode)
	}
	if errorMsg != "" {
		q.Set("error", errorMsg)
	}
	target := "/checkout"
	if encoded := q.Encode(); encoded != "" {
		target += "?" + encoded
	}
	http.Redirect(w, r, target, http.StatusSeeOther)
}

// handleCheckoutShow renders either the shipping form (once signed in as a customer) or the
// embedded register/login forms (while still anonymous) - mirrors
// web/src/app/checkout/page.tsx's `isCustomer` branch.
func (a *App) handleCheckoutShow(w http.ResponseWriter, r *http.Request) {
	items, err := a.currentCartItems(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	data := sessionFrom(r)
	authMode := r.URL.Query().Get("authMode")
	if authMode != "login" {
		authMode = "register"
	}

	view := CheckoutData{
		Base:          a.baseViewWithCartCount(r, "Checkout", items.TotalQuantity()),
		Items:         newCartLineViews(items),
		SubtotalLabel: formatMoney(items.SubtotalCents(), items.Currency()),
		IsEmpty:       len(items) == 0,
		IsCustomer:    data.IsCustomer(),
		AuthMode:      authMode,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	a.render(w, r, http.StatusOK, "checkout.html", view)
}

// handleCheckoutRegister creates a real customer account inline during checkout so the shopper's
// cart carries over without leaving the page - mirrors web/src/app/checkout/page.tsx's
// handleAccountCreated().
func (a *App) handleCheckoutRegister(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	firstName := r.FormValue("firstName")
	lastName := r.FormValue("lastName")
	email := r.FormValue("email")
	password := r.FormValue("password")
	agreedToTerms := r.FormValue("agreedToTerms") == "on"

	if message := validateRegisterForm(firstName, lastName, email, password, agreedToTerms); message != "" {
		checkoutRedirect(w, r, "register", message)
		return
	}

	auth, err := a.mudbase.Register(r.Context(), mbase.RegisterRoleCustomer, email, password, firstName, lastName, agreedToTerms)
	if err != nil {
		checkoutRedirect(w, r, "register", mbase.FriendlyMessage(err))
		return
	}
	if err := a.applyAuthSession(w, r, auth); err != nil {
		a.serverError(w, r, err)
		return
	}
	http.Redirect(w, r, "/checkout", http.StatusSeeOther)
}

// handleCheckoutLogin signs an existing shopper in during checkout without leaving the page.
func (a *App) handleCheckoutLogin(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	email := r.FormValue("email")
	password := r.FormValue("password")

	if _, err := mail.ParseAddress(email); err != nil {
		checkoutRedirect(w, r, "login", "Enter a valid email address.")
		return
	}
	if password == "" {
		checkoutRedirect(w, r, "login", "Password is required.")
		return
	}

	auth, err := a.mudbase.Login(r.Context(), email, password)
	if err != nil {
		checkoutRedirect(w, r, "login", mbase.FriendlyMessage(err))
		return
	}
	if err := a.applyAuthSession(w, r, auth); err != nil {
		a.serverError(w, r, err)
		return
	}
	http.Redirect(w, r, "/checkout", http.StatusSeeOther)
}

// validateShippingForm mirrors web/src/components/checkout/ShippingForm.tsx's zod schema.
func validateShippingForm(addr models.ShippingAddress) string {
	switch {
	case addr.FullName == "":
		return "Full name is required."
	case addr.Line1 == "":
		return "Address is required."
	case addr.City == "":
		return "City is required."
	case addr.Region == "":
		return "State/region is required."
	case addr.PostalCode == "":
		return "Postal code is required."
	case addr.Country == "":
		return "Country is required."
	default:
		return ""
	}
}

// requestBaseURL reconstructs the scheme+host this request arrived on, used to build the payment
// link's redirectUrl back to this app's own order page.
func requestBaseURL(r *http.Request) string {
	scheme := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	return scheme + "://" + r.Host
}

// handleCheckoutPlaceOrder creates the order, then requests a payment link from the shared
// checkout proxy (see internal/store.PayLinkClient) - mirrors
// web/src/app/checkout/page.tsx's placeOrder() step by step, including the KYC-gate handling.
func (a *App) handleCheckoutPlaceOrder(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}

	data := sessionFrom(r)
	if !data.IsCustomer() {
		http.Redirect(w, r, "/checkout", http.StatusSeeOther)
		return
	}

	address := models.ShippingAddress{
		FullName:   r.FormValue("fullName"),
		Line1:      r.FormValue("line1"),
		Line2:      r.FormValue("line2"),
		City:       r.FormValue("city"),
		Region:     r.FormValue("region"),
		PostalCode: r.FormValue("postalCode"),
		Country:    r.FormValue("country"),
	}
	if message := validateShippingForm(address); message != "" {
		redirectWithError(w, r, "/checkout", message)
		return
	}

	items, err := a.currentCartItems(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	if len(items) == 0 {
		redirectWithError(w, r, "/cart", "Your cart is empty — add something before checking out.")
		return
	}

	subtotalCents := items.SubtotalCents()
	token := data.AccessToken()

	order, err := a.orders.Create(r.Context(), token, store.CreateOrderInput{
		UserID:        data.UserID(),
		Items:         items,
		SubtotalCents: subtotalCents,
		Currency:      "USD",
		ShippingName:  address.FullName,
		Address:       address,
	})
	if err != nil {
		redirectWithError(w, r, "/checkout", "Something went wrong placing your order. Please try again.")
		return
	}

	amount := fmt.Sprintf("%.2f", float64(subtotalCents)/100)
	redirectURL := requestBaseURL(r) + "/orders/" + order.ID

	link, err := a.paylinks.CreatePaymentLink(r.Context(), order.ID, amount, checkoutCurrency, checkoutNetwork, redirectURL)
	if err != nil {
		var payLinkErr *store.PayLinkError
		if errors.As(err, &payLinkErr) && payLinkErr.Reason == store.PayLinkReasonKYCRequired {
			if _, statusErr := a.orders.SetOrderStatus(r.Context(), token, order.ID, models.OrderStatusPending); statusErr != nil {
				a.serverError(w, r, statusErr)
				return
			}
			redirectWithError(w, r, "/checkout", "This store's payments are still pending identity verification.")
			return
		}
		redirectWithError(w, r, "/checkout", "Couldn't start payment. Please try again.")
		return
	}

	if _, err := a.orders.SetPaymentLinkToken(r.Context(), token, order.ID, link.Token); err != nil {
		a.serverError(w, r, err)
		return
	}
	if err := a.saveCartItems(w, r, models.CartItems{}); err != nil {
		a.serverError(w, r, err)
		return
	}

	http.Redirect(w, r, "/checkout/"+link.Token, http.StatusSeeOther)
}

// PaymentData is the /checkout/{token} page's content payload.
type PaymentData struct {
	Base
	Token      string
	MudbaseURL string
}

// handlePaymentShow renders the payment-link page. All status polling happens client-side, via a
// small inline script fetching `GET {MudbaseURL}/api/payment-links/{token}` directly from the
// browser - a public, unauthenticated endpoint, exactly like
// web/src/hooks/usePaymentLinkStatus.ts.
func (a *App) handlePaymentShow(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	view := PaymentData{
		Base:       a.baseView(r, "Pay for your order"),
		Token:      token,
		MudbaseURL: a.cfg.MudbaseURL,
	}
	a.render(w, r, http.StatusOK, "payment.html", view)
}
