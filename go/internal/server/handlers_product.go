package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

// ProductDetailData is the /products/{slug} page's content payload.
type ProductDetailData struct {
	Base
	Product ProductView
	Found   bool
}

// handleProductDetail renders a single product's detail page, including its photo gallery and the
// add-to-cart form.
func (a *App) handleProductDetail(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	data := sessionFrom(r)

	product, found, err := a.catalog.BySlug(r.Context(), data.AccessToken(), slug)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := ProductDetailData{
		Base:  a.baseView(r, "Product"),
		Found: found,
	}
	if found {
		view.Product = newProductView(product)
		view.Base.Title = product.Name
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	status := http.StatusOK
	if !found {
		status = http.StatusNotFound
	}
	a.render(w, r, status, "product_detail.html", view)
}
