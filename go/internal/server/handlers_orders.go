package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

// OrdersListData is the /orders page's content payload.
type OrdersListData struct {
	Base
	Orders  []OrderView
	IsEmpty bool
}

// handleOrdersList renders the signed-in customer's own order history - route already gated by
// requireCustomer, so data.UserID() is always a real account here.
func (a *App) handleOrdersList(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	orders, err := a.orders.ListForUser(r.Context(), data.AccessToken(), data.UserID())
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := OrdersListData{
		Base:    a.baseView(r, "Your orders"),
		Orders:  newOrderViews(orders),
		IsEmpty: len(orders) == 0,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)

	a.render(w, r, http.StatusOK, "orders_list.html", view)
}

// OrderDetailData is the /orders/{id} page's content payload.
type OrderDetailData struct {
	Base
	Order         OrderView
	Items         []OrderItemView
	Address       *models.ShippingAddress
	Timeline      []TimelineStep
	ShowPayButton bool
}

// handleOrderDetail renders one order's status timeline, line items, and shipping address.
// Ownership is enforced server-side by Mudbase's `{userId: "$userId"}` condition on the
// `customer` role - a request for another shopper's order simply fails to fetch here.
func (a *App) handleOrderDetail(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)

	order, err := a.orders.ByID(r.Context(), data.AccessToken(), id)
	if err != nil {
		redirectWithError(w, r, "/orders", "This order couldn't be found.")
		return
	}

	view := OrderDetailData{
		Base:          a.baseView(r, "Order"),
		Order:         newOrderView(order),
		Items:         newOrderItemViews(order.Items(), order.Currency),
		Address:       order.Address(),
		Timeline:      newOrderTimeline(order.OrderStatus),
		ShowPayButton: order.PaymentLinkToken != "" && order.PaymentStatus != models.OrderPaymentStatusPaid,
	}

	a.render(w, r, http.StatusOK, "order_detail.html", view)
}
