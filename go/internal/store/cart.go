package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

// CartService implements the server-side half of cart persistence: the `carts` collection, one
// document per real "customer" account, upserted read-then-create-or-update because Mudbase
// collections have no native upsert endpoint (mirrors web/src/hooks/useCart.ts's persist
// mutation). Guest (anonymous-session) carts never reach here - they live entirely in the
// session cookie, see internal/session, because Mudbase's ownership-conditioned `customer`-only
// permission on this collection denies anonymous/guest writes outright.
type CartService struct {
	client       *mbase.Client
	collectionID string
}

// NewCartService builds a CartService bound to the given carts collection ID.
func NewCartService(client *mbase.Client, cartsCollectionID string) *CartService {
	return &CartService{client: client, collectionID: cartsCollectionID}
}

// ServerCart fetches userID's cart document, returning nil (not an error) when none exists yet.
func (s *CartService) ServerCart(ctx context.Context, token, userID string) (*models.Cart, error) {
	result, err := mbase.List[models.Cart](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"userId": userID},
		Limit:  1,
	})
	if err != nil {
		return nil, fmt.Errorf("store: fetching cart for user %s: %w", userID, err)
	}
	if len(result.Data) == 0 {
		return nil, nil
	}
	return &result.Data[0], nil
}

// SaveServerCart writes items as userID's cart, updating the existing document if one exists or
// creating it otherwise.
func (s *CartService) SaveServerCart(ctx context.Context, token, userID string, items models.CartItems) (models.Cart, error) {
	itemsJSON, err := models.StringifyJSONField(items)
	if err != nil {
		return models.Cart{}, fmt.Errorf("store: encoding cart items: %w", err)
	}

	existing, err := s.ServerCart(ctx, token, userID)
	if err != nil {
		return models.Cart{}, err
	}

	if existing != nil {
		updated, err := mbase.Update[models.Cart](ctx, s.client, token, s.collectionID, existing.ID, map[string]interface{}{
			"itemsJson": itemsJSON,
		})
		if err != nil {
			return models.Cart{}, fmt.Errorf("store: updating cart for user %s: %w", userID, err)
		}
		return updated, nil
	}

	created, err := mbase.Create[models.Cart](ctx, s.client, token, s.collectionID, map[string]interface{}{
		"userId":    userID,
		"itemsJson": itemsJSON,
	})
	if err != nil {
		return models.Cart{}, fmt.Errorf("store: creating cart for user %s: %w", userID, err)
	}
	return created, nil
}

// MigrateGuestCart merges a just-signed-in shopper's guest cart into their real server cart,
// creating it if this is their first server cart, or merging quantities into an existing one if
// they already had a cart from an earlier session on this account - mirrors
// web/src/hooks/useCart.ts's migrateGuestCartToServer(). A no-op when the guest cart is empty.
func (s *CartService) MigrateGuestCart(ctx context.Context, token, userID string, guestItems models.CartItems) error {
	if len(guestItems) == 0 {
		return nil
	}

	existing, err := s.ServerCart(ctx, token, userID)
	if err != nil {
		return err
	}

	merged := guestItems
	if existing != nil {
		merged = existing.Items().MergedWith(guestItems)
	}

	if _, err := s.SaveServerCart(ctx, token, userID, merged); err != nil {
		return err
	}
	return nil
}
