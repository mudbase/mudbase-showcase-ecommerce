// Package mbase wraps the real Mudbase Go SDK (github.com/mudbase/mudbase-sdk/go) with the
// storefront-specific auth and collection-data operations this app needs. It intentionally stays
// thin: every method maps to one real SDK call (or, where the vendored SDK's generated types have
// a documented gap - see auth.go - one small, clearly-commented raw HTTP call against the same
// endpoint). There is no "unified higher-level client" invented here.
package mbase

import (
	"context"
	"net/http"
	"time"

	mudbase "github.com/mudbase/mudbase-sdk/go"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/config"
)

// Client bundles the generated SDK client with the project configuration every call needs
// (project ID, collection IDs, base URL for the small raw-HTTP workarounds).
type Client struct {
	SDK        *mudbase.APIClient
	cfg        *config.Config
	httpClient *http.Client
}

// New builds a Client from the app configuration, wiring the SDK to point at the configured
// Mudbase server exactly as documented: NewConfiguration() then override Servers.
func New(cfg *config.Config) *Client {
	sdkCfg := mudbase.NewConfiguration()
	sdkCfg.Servers = mudbase.ServerConfigurations{
		{URL: cfg.MudbaseURL},
	}
	sdkCfg.HTTPClient = &http.Client{Timeout: 15 * time.Second}

	return &Client{
		SDK:        mudbase.NewAPIClient(sdkCfg),
		cfg:        cfg,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}
}

// ProjectID returns the configured Mudbase project ID.
func (c *Client) ProjectID() string {
	return c.cfg.ProjectID
}

// BaseURL returns the configured Mudbase API base URL.
func (c *Client) BaseURL() string {
	return c.cfg.MudbaseURL
}

// authedContext attaches a bearer token to ctx the way the generated SDK expects it
// (context.WithValue(ctx, mudbase.ContextAccessToken, token)) - confirmed against
// mudbase-sdk/go/configuration.go and client.go's prepareRequest, which reads exactly this key.
func authedContext(ctx context.Context, token string) context.Context {
	if token == "" {
		return ctx
	}
	return context.WithValue(ctx, mudbase.ContextAccessToken, token)
}
