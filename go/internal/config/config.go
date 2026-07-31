// Package config loads and validates every environment variable this app needs at startup.
// Failing fast here means a misconfigured deployment never serves a single request instead of
// panicking deep inside a request handler the first time a particular env var is touched.
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds every environment-derived setting the app needs, resolved once at startup.
type Config struct {
	// MudbaseURL is the Mudbase API base URL (e.g. https://cloud.mudbase.dev).
	MudbaseURL string
	// ProjectID is this app's Mudbase project ID.
	ProjectID string
	// ProductsCollectionID is the Mudbase collection ID backing the `products` collection.
	ProductsCollectionID string
	// OrdersCollectionID is the Mudbase collection ID backing the `orders` collection.
	OrdersCollectionID string
	// CartsCollectionID is the Mudbase collection ID backing the `carts` collection.
	CartsCollectionID string
	// PayLinkProxyURL is the already-deployed web app's checkout proxy endpoint. Payment-link
	// creation requires a live org owner/admin bearer session with no API-key path, so every
	// per-language reimplementation delegates to this single shared proxy instead of each
	// independently rotating the same single-use merchant refresh token (a real race condition
	// across concurrently running reimplementations) - see README "Known limitations".
	PayLinkProxyURL string
	// SessionSecret signs and encrypts the httpOnly session cookie holding the Mudbase JWT.
	SessionSecret string
	// CookieSecure sets the session cookie's Secure flag. Enable in production (HTTPS); leave off
	// for plain-HTTP local development, where a Secure cookie would silently never be sent.
	CookieSecure bool
	// Port is the local HTTP listen port.
	Port string
}

// Load reads and validates every required environment variable, returning a descriptive error
// for the first one that's missing rather than letting the zero value propagate silently.
func Load() (*Config, error) {
	cfg := &Config{
		MudbaseURL:           envOrDefault("MUDBASE_URL", "https://cloud.mudbase.dev"),
		ProjectID:            os.Getenv("MUDBASE_PROJECT_ID"),
		ProductsCollectionID: os.Getenv("MUDBASE_PRODUCTS_COLLECTION_ID"),
		OrdersCollectionID:   os.Getenv("MUDBASE_ORDERS_COLLECTION_ID"),
		CartsCollectionID:    os.Getenv("MUDBASE_CARTS_COLLECTION_ID"),
		PayLinkProxyURL: envOrDefault(
			"PAY_LINK_PROXY_URL",
			"https://mudbase-showcase-ecommerce.vercel.app/api/checkout/pay-link",
		),
		SessionSecret: os.Getenv("SESSION_SECRET"),
		CookieSecure:  envOrDefault("COOKIE_SECURE", "false") == "true",
		Port:          envOrDefault("PORT", "8080"),
	}

	required := map[string]string{
		"MUDBASE_PROJECT_ID":             cfg.ProjectID,
		"MUDBASE_PRODUCTS_COLLECTION_ID": cfg.ProductsCollectionID,
		"MUDBASE_ORDERS_COLLECTION_ID":   cfg.OrdersCollectionID,
		"MUDBASE_CARTS_COLLECTION_ID":    cfg.CartsCollectionID,
		"SESSION_SECRET":                 cfg.SessionSecret,
	}
	for name, value := range required {
		if value == "" {
			return nil, fmt.Errorf("config: missing required environment variable %s", name)
		}
	}

	if len(cfg.SessionSecret) < 32 {
		return nil, fmt.Errorf("config: SESSION_SECRET must be at least 32 characters, got %d", len(cfg.SessionSecret))
	}

	if _, err := strconv.Atoi(cfg.Port); err != nil {
		return nil, fmt.Errorf("config: PORT must be numeric: %w", err)
	}

	return cfg, nil
}

func envOrDefault(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
