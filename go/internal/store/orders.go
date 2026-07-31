package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

const sellerOrderQueueLimit = 100

// OrderService implements every operation against the `orders` collection: customer create/read
// (ownership-scoped server-side by Mudbase's `{userId: "$userId"}` condition on the `customer`
// role) and seller read/update (unconditional, for the fulfillment queue).
type OrderService struct {
	client       *mbase.Client
	collectionID string
}

// NewOrderService builds an OrderService bound to the given orders collection ID.
func NewOrderService(client *mbase.Client, ordersCollectionID string) *OrderService {
	return &OrderService{client: client, collectionID: ordersCollectionID}
}

// CreateOrderInput is everything needed to place a new order, decoupled from the Mudbase wire
// shape so the checkout handler can build it directly from cart + shipping form state.
type CreateOrderInput struct {
	UserID        string
	Items         models.CartItems
	SubtotalCents int64
	Currency      string
	ShippingName  string
	Address       models.ShippingAddress
}

// Create places a new order in "awaiting_payment" / "unpaid" state - the same starting state the
// reference web app's checkout page writes before requesting a payment link (see
// web/src/app/checkout/page.tsx's placeOrder()).
func (s *OrderService) Create(ctx context.Context, token string, in CreateOrderInput) (models.Order, error) {
	lineItems := make([]models.OrderLineItem, 0, len(in.Items))
	for _, item := range in.Items {
		lineItems = append(lineItems, models.OrderLineItem{
			ProductID:  item.ProductID,
			Name:       item.Name,
			PriceCents: item.PriceCents,
			Quantity:   item.Quantity,
		})
	}
	itemsJSON, err := models.StringifyJSONField(lineItems)
	if err != nil {
		return models.Order{}, fmt.Errorf("store: encoding order line items: %w", err)
	}
	addressJSON, err := models.StringifyJSONField(in.Address)
	if err != nil {
		return models.Order{}, fmt.Errorf("store: encoding shipping address: %w", err)
	}

	currency := in.Currency
	if currency == "" {
		currency = "USD"
	}

	body := map[string]interface{}{
		"userId":              in.UserID,
		"itemsJson":           itemsJSON,
		"subtotalCents":       in.SubtotalCents,
		"currency":            currency,
		"orderStatus":         string(models.OrderStatusAwaitingPayment),
		"shippingName":        in.ShippingName,
		"shippingAddressJson": addressJSON,
		"paymentStatus":       string(models.OrderPaymentStatusUnpaid),
	}

	order, err := mbase.Create[models.Order](ctx, s.client, token, s.collectionID, body)
	if err != nil {
		return models.Order{}, fmt.Errorf("store: creating order: %w", err)
	}
	return order, nil
}

// SetPaymentLinkToken attaches the payment link token issued for orderID after a successful
// payment-link creation call.
func (s *OrderService) SetPaymentLinkToken(ctx context.Context, token, orderID, linkToken string) (models.Order, error) {
	order, err := mbase.Update[models.Order](ctx, s.client, token, s.collectionID, orderID, map[string]interface{}{
		"paymentLinkToken": linkToken,
	})
	if err != nil {
		return models.Order{}, fmt.Errorf("store: attaching payment link to order %s: %w", orderID, err)
	}
	return order, nil
}

// SetOrderStatus updates orderID's orderStatus - used both when payment-link creation fails with
// a KYC gate (reverting to "pending") and by the seller fulfillment queue's "mark shipped" /
// "mark delivered" actions.
func (s *OrderService) SetOrderStatus(ctx context.Context, token, orderID string, status models.OrderStatus) (models.Order, error) {
	order, err := mbase.Update[models.Order](ctx, s.client, token, s.collectionID, orderID, map[string]interface{}{
		"orderStatus": string(status),
	})
	if err != nil {
		return models.Order{}, fmt.Errorf("store: updating order %s status: %w", orderID, err)
	}
	return order, nil
}

// ListForUser returns userID's own orders, newest first - mirrors web/src/app/orders/page.tsx.
func (s *OrderService) ListForUser(ctx context.Context, token, userID string) ([]models.Order, error) {
	result, err := mbase.List[models.Order](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"userId": userID},
		Sort:   "-createdAt",
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing orders for user %s: %w", userID, err)
	}
	return result.Data, nil
}

// ListAll returns every order regardless of owner, for the seller fulfillment queue - mirrors
// web/src/components/seller/SellerOrderQueue.tsx (no userId filter).
func (s *OrderService) ListAll(ctx context.Context, token string) ([]models.Order, error) {
	result, err := mbase.List[models.Order](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Sort:  "-createdAt",
		Limit: sellerOrderQueueLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing all orders: %w", err)
	}
	return result.Data, nil
}

// ByID fetches a single order by its Mudbase document ID.
func (s *OrderService) ByID(ctx context.Context, token, id string) (models.Order, error) {
	order, err := mbase.Get[models.Order](ctx, s.client, token, s.collectionID, id)
	if err != nil {
		return models.Order{}, fmt.Errorf("store: fetching order %s: %w", id, err)
	}
	return order, nil
}
