// Package server wires the storefront's HTTP surface: routing, session handling, and every
// server-rendered page handler, on top of internal/store's domain services.
package server

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/config"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/session"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/store"
)

// App bundles every dependency the HTTP handlers need.
type App struct {
	cfg       *config.Config
	sessions  *session.Store
	mudbase   *mbase.Client
	catalog   *store.Catalog
	carts     *store.CartService
	orders    *store.OrderService
	paylinks  *store.PayLinkClient
	templates *Templates
}

// New builds the App and its full dependency graph from cfg.
func New(cfg *config.Config) (*App, error) {
	templates, err := loadTemplates()
	if err != nil {
		return nil, fmt.Errorf("server: loading templates: %w", err)
	}

	client := mbase.New(cfg)

	return &App{
		cfg:       cfg,
		sessions:  session.New(cfg.SessionSecret, cfg.CookieSecure),
		mudbase:   client,
		catalog:   store.NewCatalog(client, cfg.ProductsCollectionID),
		carts:     store.NewCartService(client, cfg.CartsCollectionID),
		orders:    store.NewOrderService(client, cfg.OrdersCollectionID),
		paylinks:  store.NewPayLinkClient(cfg.PayLinkProxyURL),
		templates: templates,
	}, nil
}

// Routes builds the full chi router for this app. Static assets are mounted outside the session
// middleware group - a stylesheet request has no business establishing (or waiting on) a Mudbase
// anonymous session.
func (a *App) Routes() http.Handler {
	root := chi.NewRouter()
	root.Use(middleware.Logger)
	root.Use(middleware.Recoverer)

	staticHandler := http.FileServer(http.FS(staticFS))
	root.Get("/static/*", staticHandler.ServeHTTP)

	r := chi.NewRouter()
	r.Use(a.sessionMiddleware)

	r.Get("/", a.handleHome)
	r.Get("/products/{slug}", a.handleProductDetail)

	r.Get("/cart", a.handleCartShow)
	r.Post("/cart/add", a.handleCartAdd)
	r.Post("/cart/update", a.handleCartUpdate)
	r.Post("/cart/remove", a.handleCartRemove)

	r.Get("/login", a.handleLoginShow)
	r.Post("/login", a.handleLoginSubmit)
	r.Get("/register", a.handleRegisterShow)
	r.Post("/register", a.handleRegisterSubmit)
	r.Post("/logout", a.handleLogout)

	r.Get("/checkout", a.handleCheckoutShow)
	r.Post("/checkout/register", a.handleCheckoutRegister)
	r.Post("/checkout/login", a.handleCheckoutLogin)
	r.Post("/checkout/place-order", a.handleCheckoutPlaceOrder)
	r.Get("/checkout/{token}", a.handlePaymentShow)

	r.Route("/orders", func(r chi.Router) {
		r.Use(a.requireCustomer)
		r.Get("/", a.handleOrdersList)
		r.Get("/{id}", a.handleOrderDetail)
	})

	r.Route("/seller", func(r chi.Router) {
		r.Use(a.requireSeller)
		r.Get("/", a.handleSellerDashboard)
		r.Get("/orders/fragment", a.handleSellerOrdersFragment)
		r.Post("/orders/{id}/advance", a.handleSellerAdvanceOrder)
		r.Get("/products/new", a.handleSellerProductNewShow)
		r.Post("/products/new", a.handleSellerProductNewSubmit)
		r.Get("/products/{id}/edit", a.handleSellerProductEditShow)
		r.Post("/products/{id}/edit", a.handleSellerProductEditSubmit)
		r.Post("/products/{id}/delete", a.handleSellerProductDelete)
	})

	root.Mount("/", r)
	return root
}

// baseView builds the Base view fields shared by every page from the current request's session,
// fetching the cart count itself. Handlers that already loaded the cart's contents for their own
// page (cart, checkout) should call baseViewWithCartCount instead to avoid a redundant fetch.
func (a *App) baseView(r *http.Request, title string) Base {
	return a.baseViewWithCartCount(r, title, a.cartCount(r))
}

// baseViewWithCartCount builds the Base view fields using an already-known cart count.
func (a *App) baseViewWithCartCount(r *http.Request, title string, cartCount int64) Base {
	data := sessionFrom(r)
	return Base{
		Title:      title,
		IsSignedIn: data.IsSignedIn(),
		IsSeller:   data.IsSeller(),
		FirstName:  data.FirstName(),
		CartCount:  cartCount,
	}
}

// cartCount resolves the header cart-count badge for the current request: the server-side
// `carts` document for a signed-in customer, or the session-cookie guest cart otherwise. A failed
// lookup degrades to 0 rather than failing the whole page - the badge is a convenience, not a
// correctness-critical value.
func (a *App) cartCount(r *http.Request) int64 {
	data := sessionFrom(r)
	if !data.IsCustomer() {
		return data.GuestCart().TotalQuantity()
	}
	cart, err := a.carts.ServerCart(r.Context(), data.AccessToken(), data.UserID())
	if err != nil || cart == nil {
		return 0
	}
	return cart.Items().TotalQuantity()
}
