package server

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"net/url"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/session"
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

		r = r.WithContext(mbase.WithTokenRefresher(r.Context(), a.tokenRefresher(w, r, data)))
		next.ServeHTTP(w, withSession(r, data))
	})
}

// tokenRefresher builds the mbase.TokenRefresher this request's context carries, so any
// List/Get/Create/Update/Delete call made against internal/store deep in a handler can
// transparently recover from an expired access token: on a 401, mbase.callWithRefresh (see
// internal/mbase/refresh.go) invokes this closure, which exchanges the session's stored refresh
// token for a new pair via a.mudbase.Refresh, persists both back into the session cookie, and
// hands the new access token back for one retry - mirrors the reference web app's axios response
// interceptor (web/src/lib/mudbase-provider.tsx) instead of surfacing a raw 401 to the shopper.
func (a *App) tokenRefresher(w http.ResponseWriter, r *http.Request, data *session.Data) mbase.TokenRefresher {
	return func(ctx context.Context) (string, error) {
		refreshToken := data.RefreshToken()
		if refreshToken == "" {
			return "", fmt.Errorf("server: session has no refresh token to use")
		}

		result, err := a.mudbase.Refresh(ctx, refreshToken)
		if err != nil {
			return "", fmt.Errorf("server: refreshing access token: %w", err)
		}

		data.SetTokens(result.Token, result.RefreshToken)
		if err := data.Save(w, r); err != nil {
			return "", fmt.Errorf("server: persisting refreshed session token: %w", err)
		}
		return result.Token, nil
	}
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
