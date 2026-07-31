package store

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// PayLinkReason enumerates the failure reasons the shared checkout proxy returns.
type PayLinkReason string

const (
	PayLinkReasonKYCRequired      PayLinkReason = "kyc_required"
	PayLinkReasonMerchantAuthFail PayLinkReason = "merchant_auth_failed"
	PayLinkReasonUnknown          PayLinkReason = "unknown"
)

// PayLinkError is returned when the proxy responds with a non-2xx status, carrying the reason so
// callers can show an honest "payments pending identity verification" message for a KYC gate
// instead of a generic failure (see web/src/lib/mudbase-server.ts's CreatePaymentLinkResult).
type PayLinkError struct {
	Reason  PayLinkReason
	Message string
}

func (e *PayLinkError) Error() string {
	return fmt.Sprintf("pay-link proxy: %s: %s", e.Reason, e.Message)
}

// PayLink is the Mudbase payment-link object the proxy returns on success.
type PayLink struct {
	Token       string  `json:"token"`
	Amount      *string `json:"amount"`
	Currency    string  `json:"currency"`
	Network     string  `json:"network"`
	Address     string  `json:"address"`
	Description *string `json:"description"`
	RedirectURL *string `json:"redirectUrl"`
	Status      string  `json:"status"`
	ExpiresAt   *string `json:"expiresAt"`
}

// PayLinkClient calls the already-deployed reference web app's `/api/checkout/pay-link` proxy.
// Payment-link creation requires a live Mudbase org owner/admin bearer session with no API-key
// path; rather than every per-language reimplementation independently rotating the same
// single-use merchant refresh token (a real race condition when multiple apps run concurrently),
// every reimplementation delegates to this one shared endpoint - see README "Known limitations".
type PayLinkClient struct {
	proxyURL   string
	httpClient *http.Client
}

// NewPayLinkClient builds a PayLinkClient pointed at proxyURL.
func NewPayLinkClient(proxyURL string) *PayLinkClient {
	return &PayLinkClient{
		proxyURL:   proxyURL,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}
}

type payLinkRequest struct {
	OrderID     string `json:"orderId"`
	Amount      string `json:"amount"`
	Currency    string `json:"currency"`
	Network     string `json:"network"`
	RedirectURL string `json:"redirectUrl"`
}

type payLinkSuccessResponse struct {
	Link PayLink `json:"link"`
}

type payLinkErrorResponse struct {
	Error  string `json:"error"`
	Reason string `json:"reason"`
}

// CreatePaymentLink requests a payment link for orderID. amount is a decimal string (e.g.
// "129.99"), currency/network match the reference app's fixed choice for this demo storefront
// ("USDC"/"POLYGON" - see web/src/app/checkout/page.tsx), and redirectUrl is where the Mudbase
// hosted payment flow sends the shopper back to after paying.
func (c *PayLinkClient) CreatePaymentLink(ctx context.Context, orderID, amount, currency, network, redirectURL string) (PayLink, error) {
	payload := payLinkRequest{
		OrderID:     orderID,
		Amount:      amount,
		Currency:    currency,
		Network:     network,
		RedirectURL: redirectURL,
	}
	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return PayLink{}, fmt.Errorf("store: encoding pay-link request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.proxyURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return PayLink{}, fmt.Errorf("store: building pay-link request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return PayLink{}, fmt.Errorf("store: calling pay-link proxy: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return PayLink{}, fmt.Errorf("store: reading pay-link proxy response: %w", err)
	}

	if resp.StatusCode >= 300 {
		var errBody payLinkErrorResponse
		_ = json.Unmarshal(respBody, &errBody)
		reason := PayLinkReason(errBody.Reason)
		if reason == "" {
			reason = PayLinkReasonUnknown
		}
		message := errBody.Error
		if message == "" {
			message = fmt.Sprintf("pay-link proxy returned %s", resp.Status)
		}
		return PayLink{}, &PayLinkError{Reason: reason, Message: message}
	}

	var success payLinkSuccessResponse
	if err := json.Unmarshal(respBody, &success); err != nil {
		return PayLink{}, fmt.Errorf("store: decoding pay-link proxy response: %w", err)
	}
	return success.Link, nil
}
