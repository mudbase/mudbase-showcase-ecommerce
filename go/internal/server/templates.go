package server

import (
	"embed"
	"fmt"
	"html/template"
	"net/http"
)

//go:embed templates/*.html
var templatesFS embed.FS

//go:embed static/*
var staticFS embed.FS

// pageNames lists every page template file (besides layout.html), each of which must define a
// `{{define "content"}}` block. Listing them explicitly (rather than globbing at request time)
// means a missing/misnamed template file fails at startup, not on the first visit to that page.
var pageNames = []string{
	"home.html",
	"product_detail.html",
	"cart.html",
	"checkout.html",
	"payment.html",
	"orders_list.html",
	"order_detail.html",
	"login.html",
	"register.html",
	"seller_dashboard.html",
	"seller_orders_fragment.html",
	"seller_product_form.html",
}

// funcMap is available to every page template.
var funcMap = template.FuncMap{
	"formatMoney": formatMoney,
	"formatDate":  formatDate,
	"add1":        func(i int) int { return i + 1 },
}

// Templates is a registry of one fully-parsed (layout + page) template.Template per page name.
type Templates struct {
	pages map[string]*template.Template
}

// loadTemplates parses layout.html together with each page file into its own template set, so
// every page can define its own `{{define "content"}}` block without colliding with the others.
func loadTemplates() (*Templates, error) {
	pages := make(map[string]*template.Template, len(pageNames))
	for _, name := range pageNames {
		tmpl, err := template.New("layout.html").Funcs(funcMap).ParseFS(
			templatesFS, "templates/layout.html", "templates/partials.html", "templates/"+name,
		)
		if err != nil {
			return nil, fmt.Errorf("server: parsing template %s: %w", name, err)
		}
		pages[name] = tmpl
	}
	return &Templates{pages: pages}, nil
}

// Render executes the named page's layout+content into w. It buffers nothing - a template error
// partway through would otherwise corrupt an already-flushed response, which is an acceptable
// tradeoff for a reference app's straightforward pages (none stream large bodies).
func (t *Templates) Render(w http.ResponseWriter, status int, name string, data interface{}) error {
	tmpl, ok := t.pages[name]
	if !ok {
		return fmt.Errorf("server: no template registered for %q", name)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if err := tmpl.ExecuteTemplate(w, "layout.html", data); err != nil {
		return fmt.Errorf("server: rendering template %q: %w", name, err)
	}
	return nil
}

// RenderFragment executes just a page's "content" block, without the surrounding layout - used by
// endpoints a small poll script fetches to refresh part of an already-loaded page (see
// handleSellerOrdersFragment).
func (t *Templates) RenderFragment(w http.ResponseWriter, status int, name string, data interface{}) error {
	tmpl, ok := t.pages[name]
	if !ok {
		return fmt.Errorf("server: no template registered for %q", name)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	if err := tmpl.ExecuteTemplate(w, "content", data); err != nil {
		return fmt.Errorf("server: rendering fragment %q: %w", name, err)
	}
	return nil
}
