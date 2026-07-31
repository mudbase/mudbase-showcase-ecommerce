// Package models defines the storefront's domain types and the JSON-string-field convention
// Mudbase Collections require for anything array/object shaped.
package models

import "encoding/json"

// ParseJSONField decodes a JSON-encoded string field into T, returning fallback on an empty or
// malformed value. Mudbase Collection fields have a fixed type enum (string, number, boolean,
// date, email, url, enum, reference) with no native array/object type, so order line items,
// shipping addresses, and extra product image URLs are stored JSON-encoded in a string field and
// parsed at the edges - a documented constraint of the platform's Collections feature, not a
// workaround specific to this app (see web/README.md "Known limitations").
func ParseJSONField[T any](value string, fallback T) T {
	if value == "" {
		return fallback
	}
	var out T
	if err := json.Unmarshal([]byte(value), &out); err != nil {
		return fallback
	}
	return out
}

// StringifyJSONField encodes a value as a JSON string for storage in a Mudbase string field.
func StringifyJSONField[T any](value T) (string, error) {
	b, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	return string(b), nil
}
