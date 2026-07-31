package mbase

import (
	"encoding/json"
	"errors"
	"fmt"

	mudbase "github.com/mudbase/mudbase-sdk/go"
)

// wireError is the common {"error": "...", "message": "..."} shape Mudbase's REST API returns on
// failure - both the SDK's GenericOpenAPIError body and this app's raw-HTTP workarounds use it.
type wireError struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// userFacingError carries a message already clean enough to show a shopper directly (extracted
// from a wire {error}/{message} body outside the generated SDK's own error path - see Register's
// raw HTTP call). FriendlyMessage recognizes it so callers don't have to care which code path
// produced the error.
type userFacingError struct {
	message string
}

func (e *userFacingError) Error() string { return e.message }

func newUserFacingError(message string) error {
	return &userFacingError{message: message}
}

// FriendlyMessage extracts a human-readable message from an error returned by this package. The
// generated SDK client wraps every non-2xx response in a *mudbase.GenericOpenAPIError carrying the
// raw response body (see mudbase-sdk/go/client.go); this unwraps that body's {error} or {message}
// field instead of surfacing the generic "400 Bad Request"-style Error() string. It also
// recognizes userFacingError, produced by this package's own raw-HTTP workarounds.
func FriendlyMessage(err error) string {
	if err == nil {
		return ""
	}

	var userErr *userFacingError
	if errors.As(err, &userErr) {
		return userErr.message
	}

	var apiErr *mudbase.GenericOpenAPIError
	if errors.As(err, &apiErr) {
		var wire wireError
		if jsonErr := json.Unmarshal(apiErr.Body(), &wire); jsonErr == nil {
			if wire.Error != "" {
				return wire.Error
			}
			if wire.Message != "" {
				return wire.Message
			}
		}
	}
	return err.Error()
}

// wrapAPIError produces a consistently-formatted, %w-wrapped error carrying the friendly message
// as context, per this project's "every error wrapped with fmt.Errorf" rule.
func wrapAPIError(action string, err error) error {
	return fmt.Errorf("%s: %s: %w", action, FriendlyMessage(err), err)
}
