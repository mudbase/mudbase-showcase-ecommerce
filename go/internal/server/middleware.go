package server

import (
	"log"
	"net/http"
	"net/url"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
)

// sessionMiddleware loads the visitor's session cookie and, on a first visit (no access token
// yet), establishes a Mudbase anonymous session so the catalog's `authenticated`-role read
// permission resolves without forcing signup - mirrors
// web/src/lib/mudbase-provider.tsx's guest-browsing bootstrap.
func (a *App) sessionMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		data, err := a.sessions.Load(r)
		if err != nil {
			log.Printf("server: session load failed: %v", err)
			http.Error(w, "Session error. Please clear your cookies and try again.", http.StatusInternalServerError)
			return
		}

		if data.AccessToken() == "" {
			auth, err := a.mudbase.CreateAnonymousSession(r.Context())
			if err != nil {
				log.Printf("server: anonymous session failed: %v", mbase.FriendlyMessage(err))
				http.Error(w, "Couldn't start a browsing session right now. Please try again shortly.", http.StatusBadGateway)
				return
			}
			data.SetUser(auth)
			if err := data.Save(w, r); err != nil {
				log.Printf("server: session save failed: %v", err)
				http.Error(w, "Session error. Please try again.", http.StatusInternalServerError)
				return
			}
		}

		next.ServeHTTP(w, withSession(r, data))
	})
}

// requireCustomer gates a route on a real signed-in "customer" account, redirecting anonymous and
// seller sessions to sign in first (mirrors web/src/app/orders' auth-guard note in
// web/plan/build-plan.md: "authenticated (real account only) - redirects anonymous users to
// register/login").
func (a *App) requireCustomer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !sessionFrom(r).IsCustomer() {
			redirectTo := "/login?redirect=" + url.QueryEscape(r.URL.Path)
			http.Redirect(w, r, redirectTo, http.StatusSeeOther)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// requireSeller gates a route on customRole == "seller", redirecting everyone else home - mirrors
// web/src/components/seller/SellerGuard.tsx.
func (a *App) requireSeller(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !sessionFrom(r).IsSeller() {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		next.ServeHTTP(w, r)
	})
}
