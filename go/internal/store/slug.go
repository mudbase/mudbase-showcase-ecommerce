// Package store implements the storefront's domain operations (catalog, cart, checkout, orders)
// on top of internal/mbase's thin Mudbase SDK wrapper, keeping the HTTP handlers themselves free
// of any Mudbase-specific request shaping.
package store

import (
	"crypto/rand"
	"math/big"
	"regexp"
	"strings"
)

var slugDisallowed = regexp.MustCompile(`[^a-z0-9]+`)
var slugTrim = regexp.MustCompile(`(^-|-$)`)

const slugSuffixAlphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
const slugSuffixLength = 6

// slugify mirrors web/src/lib/utils.ts's slugify(): lowercase, non-alphanumeric runs collapsed to
// a single hyphen, leading/trailing hyphens trimmed.
func slugify(value string) string {
	lower := strings.ToLower(strings.TrimSpace(value))
	collapsed := slugDisallowed.ReplaceAllString(lower, "-")
	return slugTrim.ReplaceAllString(collapsed, "")
}

// newProductSlug builds a unique-enough product slug: `slugify(name)-<6 random base36 chars>`,
// mirroring web/src/app/seller/products/new/page.tsx's
// `${slugify(values.name)}-${Math.random().toString(36).slice(2, 8)}`.
func newProductSlug(name string) (string, error) {
	suffix := make([]byte, slugSuffixLength)
	for i := range suffix {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(slugSuffixAlphabet))))
		if err != nil {
			return "", err
		}
		suffix[i] = slugSuffixAlphabet[n.Int64()]
	}
	return slugify(name) + "-" + string(suffix), nil
}
