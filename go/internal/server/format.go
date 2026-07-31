package server

import (
	"fmt"
	"time"
)

// currencySymbols covers the currencies this demo storefront actually uses (USD for prices,
// USDC for the on-chain payment amount) - not a general-purpose i18n formatter.
var currencySymbols = map[string]string{
	"USD": "$",
}

// formatMoney renders cents as a currency amount, mirroring web/src/lib/utils.ts's formatMoney()
// closely enough for this demo's fixed currency set without pulling in a full ICU library.
func formatMoney(cents int64, currency string) string {
	amount := float64(cents) / 100
	if symbol, ok := currencySymbols[currency]; ok {
		return fmt.Sprintf("%s%.2f", symbol, amount)
	}
	return fmt.Sprintf("%.2f %s", amount, currency)
}

// formatDate parses an RFC3339 timestamp (as returned by Mudbase's createdAt/updatedAt fields) and
// renders it in a medium, readable form. Malformed or empty input renders as "-" rather than
// panicking or leaking a raw parse error into the page.
func formatDate(iso string) string {
	t, err := time.Parse(time.RFC3339, iso)
	if err != nil {
		return "-"
	}
	return t.Local().Format("Jan 2, 2006, 3:04 PM")
}
