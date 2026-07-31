package server

import (
	"net/http"
	"sort"
)

// HomeData is the /  page's content payload.
type HomeData struct {
	Base
	Products       []ProductView
	Categories     []string
	ActiveCategory string
}

// handleHome renders the product catalog, optionally narrowed by ?category=.
func (a *App) handleHome(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	category := r.URL.Query().Get("category")

	products, err := a.catalog.ListActive(r.Context(), data.AccessToken(), category)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	// Mirrors web/src/components/catalog/ProductGrid.tsx exactly: the category filter bar is
	// built from the *already-filtered* result set, not the full catalog, so selecting one
	// category temporarily narrows the filter bar to just that category until "All" is clicked.
	categorySet := make(map[string]struct{})
	for _, p := range products {
		if p.Category != "" {
			categorySet[p.Category] = struct{}{}
		}
	}
	categories := make([]string, 0, len(categorySet))
	for c := range categorySet {
		categories = append(categories, c)
	}
	sort.Strings(categories)

	view := HomeData{
		Base:           a.baseView(r, ""),
		Products:       newProductViews(products),
		Categories:     categories,
		ActiveCategory: category,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	a.render(w, r, http.StatusOK, "home.html", view)
}
