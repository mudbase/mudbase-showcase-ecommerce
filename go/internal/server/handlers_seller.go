package server

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/store"
)

// maxGalleryPhotos mirrors web/src/components/seller/ProductForm.tsx's MAX_GALLERY_PHOTOS. This
// server-rendered form renders that many gallery-URL input slots up front (rather than a
// JS-driven "add photo" button) - a deliberate simplification for a no-SPA-framework app, see
// README "Known limitations". Blank slots are simply ignored on submit.
const maxGalleryPhotos = 8

// SellerOrdersView is the order-queue payload shared by the full dashboard page and the
// poll-refreshed fragment endpoint.
type SellerOrdersView struct {
	Orders      []OrderView
	OrdersEmpty bool
}

// SellerDashboardData is the /seller page's content payload.
type SellerDashboardData struct {
	Base
	SellerOrdersView
	Products      []ProductView
	ProductsEmpty bool
}

func (a *App) sellerOrdersView(r *http.Request) (SellerOrdersView, error) {
	data := sessionFrom(r)
	orders, err := a.orders.ListAll(r.Context(), data.AccessToken())
	if err != nil {
		return SellerOrdersView{}, err
	}
	return SellerOrdersView{Orders: newOrderViews(orders), OrdersEmpty: len(orders) == 0}, nil
}

// handleSellerDashboard renders the fulfillment queue and product table. Route already gated by
// requireSeller.
func (a *App) handleSellerDashboard(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)

	ordersView, err := a.sellerOrdersView(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	products, err := a.catalog.ListAllForSeller(r.Context(), data.AccessToken())
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := SellerDashboardData{
		Base:             a.baseView(r, "Seller dashboard"),
		SellerOrdersView: ordersView,
		Products:         newProductViews(products),
		ProductsEmpty:    len(products) == 0,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	a.render(w, r, http.StatusOK, "seller_dashboard.html", view)
}

// handleSellerOrdersFragment renders just the order-queue list (no layout), polled every few
// seconds by a small inline script on the dashboard page. This is this app's stand-in for the
// reference web app's Socket.IO realtime subscription - see README "Known limitations": there is
// no official Mudbase Go realtime client, so the fulfillment queue refreshes via polling instead
// of a push subscription, which is functionally equivalent for this use case.
func (a *App) handleSellerOrdersFragment(w http.ResponseWriter, r *http.Request) {
	ordersView, err := a.sellerOrdersView(r)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	if err := a.templates.RenderFragment(w, http.StatusOK, "seller_orders_fragment.html", ordersView); err != nil {
		a.serverError(w, r, err)
	}
}

// handleSellerAdvanceOrder moves an order to its next fulfillment status (paid -> shipped ->
// delivered), mirroring web/src/components/seller/SellerOrderQueue.tsx's NEXT_STATUS map.
func (a *App) handleSellerAdvanceOrder(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)

	order, err := a.orders.ByID(r.Context(), data.AccessToken(), id)
	if err != nil {
		redirectWithError(w, r, "/seller", "Couldn't update that order.")
		return
	}
	next, ok := order.OrderStatus.NextStatus()
	if !ok {
		http.Redirect(w, r, "/seller", http.StatusSeeOther)
		return
	}
	if _, err := a.orders.SetOrderStatus(r.Context(), data.AccessToken(), id, next); err != nil {
		redirectWithError(w, r, "/seller", "Couldn't update that order.")
		return
	}
	http.Redirect(w, r, "/seller", http.StatusSeeOther)
}

// ProductFormValues holds a product form's raw string field values, used both to pre-populate the
// edit form and to re-render a submission that failed validation without losing the seller's
// input.
type ProductFormValues struct {
	Name                string
	Description         string
	PriceCents          string
	CompareAtPriceCents string
	Currency            string
	ImageURL            string
	Category            string
	Stock               string
	IsActive            bool
	GalleryURLs         []string
}

func newEmptyProductFormValues() ProductFormValues {
	return ProductFormValues{
		Currency:    "USD",
		IsActive:    true,
		GalleryURLs: make([]string, maxGalleryPhotos),
	}
}

// ProductFormData is the /seller/products/new and /seller/products/{id}/edit page's content
// payload.
type ProductFormData struct {
	Base
	IsEdit    bool
	ProductID string
	Action    string
	Values    ProductFormValues
}

func (a *App) handleSellerProductNewShow(w http.ResponseWriter, r *http.Request) {
	view := ProductFormData{
		Base:   a.baseView(r, "Add product"),
		Action: "/seller/products/new",
		Values: newEmptyProductFormValues(),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "seller_product_form.html", view)
}

// parseProductForm reads and validates a submitted product form, returning the parsed
// store.ProductInput plus the raw values (for re-rendering on error) and a validation message
// ("" when valid) - mirrors web/src/components/seller/ProductForm.tsx's zod schema.
func parseProductForm(r *http.Request) (store.ProductInput, ProductFormValues, string) {
	values := ProductFormValues{
		Name:                strings.TrimSpace(r.FormValue("name")),
		Description:         r.FormValue("description"),
		PriceCents:          r.FormValue("priceCents"),
		CompareAtPriceCents: r.FormValue("compareAtPriceCents"),
		Currency:            r.FormValue("currency"),
		ImageURL:            r.FormValue("imageUrl"),
		Category:            r.FormValue("category"),
		Stock:               r.FormValue("stock"),
		IsActive:            r.FormValue("isActive") == "on",
		GalleryURLs:         make([]string, maxGalleryPhotos),
	}
	for i := 0; i < maxGalleryPhotos; i++ {
		values.GalleryURLs[i] = r.FormValue("galleryUrl" + strconv.Itoa(i))
	}

	if values.Name == "" {
		return store.ProductInput{}, values, "Name is required."
	}
	if values.Currency == "" {
		values.Currency = "USD"
	}

	priceCents, err := strconv.ParseInt(values.PriceCents, 10, 64)
	if err != nil || priceCents < 0 {
		return store.ProductInput{}, values, "Price can't be negative."
	}
	stock, err := strconv.ParseInt(values.Stock, 10, 64)
	if err != nil || stock < 0 {
		return store.ProductInput{}, values, "Stock can't be negative."
	}

	var compareAtPriceCents *int64
	if trimmed := strings.TrimSpace(values.CompareAtPriceCents); trimmed != "" {
		parsed, err := strconv.ParseInt(trimmed, 10, 64)
		if err != nil || parsed < 0 {
			return store.ProductInput{}, values, "Compare-at price can't be negative."
		}
		if parsed <= priceCents {
			return store.ProductInput{}, values, "Compare-at price must be higher than the current price."
		}
		compareAtPriceCents = &parsed
	}

	galleryURLs := make([]string, 0, maxGalleryPhotos)
	for _, url := range values.GalleryURLs {
		if trimmed := strings.TrimSpace(url); trimmed != "" {
			galleryURLs = append(galleryURLs, trimmed)
		}
	}

	input := store.ProductInput{
		Name:                values.Name,
		Description:         values.Description,
		PriceCents:          priceCents,
		CompareAtPriceCents: compareAtPriceCents,
		Currency:            values.Currency,
		ImageURL:            values.ImageURL,
		Category:            values.Category,
		Stock:               stock,
		IsActive:            values.IsActive,
		GalleryURLs:         galleryURLs,
	}
	return input, values, ""
}

func (a *App) handleSellerProductNewSubmit(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	input, values, message := parseProductForm(r)
	if message != "" {
		view := ProductFormData{
			Base:   a.baseView(r, "Add product"),
			Action: "/seller/products/new",
			Values: values,
		}
		view.FlashError = message
		a.render(w, r, http.StatusUnprocessableEntity, "seller_product_form.html", view)
		return
	}

	data := sessionFrom(r)
	if _, err := a.catalog.Create(r.Context(), data.AccessToken(), data.UserID(), input); err != nil {
		view := ProductFormData{
			Base:   a.baseView(r, "Add product"),
			Action: "/seller/products/new",
			Values: values,
		}
		view.FlashError = "Couldn't save that product. Please try again."
		a.render(w, r, http.StatusBadGateway, "seller_product_form.html", view)
		return
	}

	http.Redirect(w, r, "/seller", http.StatusSeeOther)
}

func (a *App) handleSellerProductEditShow(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)

	product, err := a.catalog.ByID(r.Context(), data.AccessToken(), id)
	if err != nil {
		redirectWithError(w, r, "/seller", "That product couldn't be found.")
		return
	}

	// Read galleryJson directly rather than product.Gallery(), which prepends the main image only
	// when ImageURL is non-empty - relying on it here would misalign the "additional photos" slots
	// by one whenever a product has gallery extras but no main image set.
	extra := models.ParseJSONField[[]string](product.GalleryJSON, nil)
	galleryValues := make([]string, maxGalleryPhotos)
	copy(galleryValues, extra)

	compareAtPriceCents := ""
	if product.CompareAtPriceCents != nil {
		compareAtPriceCents = strconv.FormatInt(*product.CompareAtPriceCents, 10)
	}

	view := ProductFormData{
		Base:      a.baseView(r, "Edit product"),
		IsEdit:    true,
		ProductID: id,
		Action:    "/seller/products/" + id + "/edit",
		Values: ProductFormValues{
			Name:                product.Name,
			Description:         product.Description,
			PriceCents:          strconv.FormatInt(product.PriceCents, 10),
			CompareAtPriceCents: compareAtPriceCents,
			Currency:            product.Currency,
			ImageURL:            product.ImageURL,
			Category:            product.Category,
			Stock:               strconv.FormatInt(product.Stock, 10),
			IsActive:            product.IsActive,
			GalleryURLs:         galleryValues,
		},
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	a.render(w, r, http.StatusOK, "seller_product_form.html", view)
}

func (a *App) handleSellerProductEditSubmit(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	input, values, message := parseProductForm(r)
	if message != "" {
		view := ProductFormData{
			Base:      a.baseView(r, "Edit product"),
			IsEdit:    true,
			ProductID: id,
			Action:    "/seller/products/" + id + "/edit",
			Values:    values,
		}
		view.FlashError = message
		a.render(w, r, http.StatusUnprocessableEntity, "seller_product_form.html", view)
		return
	}

	data := sessionFrom(r)
	if _, err := a.catalog.Update(r.Context(), data.AccessToken(), id, input); err != nil {
		view := ProductFormData{
			Base:      a.baseView(r, "Edit product"),
			IsEdit:    true,
			ProductID: id,
			Action:    "/seller/products/" + id + "/edit",
			Values:    values,
		}
		view.FlashError = "Couldn't save that product. Please try again."
		a.render(w, r, http.StatusBadGateway, "seller_product_form.html", view)
		return
	}

	http.Redirect(w, r, "/seller", http.StatusSeeOther)
}

func (a *App) handleSellerProductDelete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)
	if err := a.catalog.Delete(r.Context(), data.AccessToken(), id); err != nil {
		redirectWithError(w, r, "/seller", "Couldn't delete that product. Please try again.")
		return
	}
	http.Redirect(w, r, "/seller", http.StatusSeeOther)
}
