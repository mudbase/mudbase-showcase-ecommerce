package server

import (
	"io"
	"net/http/httptest"
	"testing"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

// sampleProduct returns a representative Product for template smoke tests.
func sampleProduct() models.Product {
	compareAt := int64(2999)
	return models.Product{
		ID:                  "prod123456",
		CreatedAt:           "2026-07-01T12:00:00Z",
		Name:                "Field Notebook",
		Slug:                "field-notebook-ab12cd",
		Description:         "A sturdy notebook.",
		PriceCents:          1999,
		CompareAtPriceCents: &compareAt,
		Currency:            "USD",
		ImageURL:            "https://example.com/notebook.jpg",
		GalleryJSON:         `["https://example.com/notebook-2.jpg"]`,
		Category:            "Stationery",
		Stock:               5,
		IsActive:            true,
		SellerID:            "seller123",
	}
}

func sampleOrder() models.Order {
	return models.Order{
		ID:                  "order1234567890",
		CreatedAt:           "2026-07-01T12:00:00Z",
		UserID:              "user123",
		ItemsJSON:           `[{"productId":"prod123456","name":"Field Notebook","priceCents":1999,"quantity":2}]`,
		SubtotalCents:       3998,
		Currency:            "USD",
		OrderStatus:         models.OrderStatusPaid,
		ShippingName:        "Ada Lovelace",
		ShippingAddressJSON: `{"fullName":"Ada Lovelace","line1":"1 Analytical Engine Way","city":"London","region":"","postalCode":"SW1A","country":"UK"}`,
		PaymentLinkToken:    "tok_abc123",
		PaymentStatus:       models.OrderPaymentStatusPaid,
	}
}

// TestTemplatesRenderEveryPage parses the full embedded template set and renders every page with
// representative data, catching template typos/missing-field errors that go build/go vet cannot -
// no live Mudbase project is needed since this only exercises html/template execution.
func TestTemplatesRenderEveryPage(t *testing.T) {
	templates, err := loadTemplates()
	if err != nil {
		t.Fatalf("loadTemplates: %v", err)
	}

	product := sampleProduct()
	order := sampleOrder()
	productView := newProductView(product)
	orderView := newOrderView(order)

	// seller_orders_fragment.html is rendered via RenderFragment (no layout) in real handlers -
	// see handleSellerOrdersFragment - so it's exercised separately below rather than through the
	// full-page Render cases.
	fragmentRec := httptest.NewRecorder()
	if err := templates.RenderFragment(fragmentRec, 200, "seller_orders_fragment.html", SellerOrdersView{Orders: []OrderView{orderView}}); err != nil {
		t.Errorf("rendering fragment seller_orders_fragment.html: %v", err)
	} else if body, _ := io.ReadAll(fragmentRec.Result().Body); len(body) == 0 {
		t.Error("rendering fragment seller_orders_fragment.html produced an empty body")
	}

	cases := []struct {
		name string
		data interface{}
	}{
		{"home.html", HomeData{
			Base:           Base{Title: "Home"},
			Products:       []ProductView{productView},
			Categories:     []string{"Stationery"},
			ActiveCategory: "",
		}},
		{"product_detail.html", ProductDetailData{
			Base:    Base{Title: product.Name},
			Product: productView,
			Found:   true,
		}},
		{"product_detail.html", ProductDetailData{Base: Base{Title: "Product"}, Found: false}},
		{"cart.html", CartData{
			Base:          Base{Title: "Your cart"},
			Items:         newCartLineViews(models.CartItems{{ProductID: "p1", Name: "Item", PriceCents: 500, Currency: "USD", Quantity: 2}}),
			IsEmpty:       false,
			SubtotalLabel: "$10.00",
		}},
		{"cart.html", CartData{Base: Base{Title: "Your cart"}, IsEmpty: true}},
		{"checkout.html", CheckoutData{
			Base:          Base{Title: "Checkout"},
			Items:         newCartLineViews(models.CartItems{{ProductID: "p1", Name: "Item", PriceCents: 500, Currency: "USD", Quantity: 2}}),
			SubtotalLabel: "$10.00",
			IsCustomer:    false,
			AuthMode:      "register",
		}},
		{"checkout.html", CheckoutData{Base: Base{Title: "Checkout"}, IsCustomer: true, AuthMode: "login"}},
		{"payment.html", PaymentData{Base: Base{Title: "Pay"}, Token: "tok_abc123", MudbaseURL: "https://cloud.mudbase.dev"}},
		{"orders_list.html", OrdersListData{Base: Base{Title: "Orders"}, Orders: []OrderView{orderView}}},
		{"orders_list.html", OrdersListData{Base: Base{Title: "Orders"}, IsEmpty: true}},
		{"order_detail.html", OrderDetailData{
			Base:          Base{Title: "Order"},
			Order:         orderView,
			Items:         newOrderItemViews(order.Items(), order.Currency),
			Address:       order.Address(),
			Timeline:      newOrderTimeline(order.OrderStatus),
			ShowPayButton: false,
		}},
		{"login.html", LoginData{Base: Base{Title: "Sign in"}}},
		{"register.html", RegisterData{Base: Base{Title: "Register"}}},
		{"seller_dashboard.html", SellerDashboardData{
			Base:             Base{Title: "Seller"},
			SellerOrdersView: SellerOrdersView{Orders: []OrderView{orderView}},
			Products:         []ProductView{productView},
		}},
		{"seller_product_form.html", ProductFormData{
			Base:   Base{Title: "Add product"},
			Action: "/seller/products/new",
			Values: newEmptyProductFormValues(),
		}},
	}

	for _, tc := range cases {
		rec := httptest.NewRecorder()
		if err := templates.Render(rec, 200, tc.name, tc.data); err != nil {
			t.Errorf("rendering %s: %v", tc.name, err)
			continue
		}
		body, err := io.ReadAll(rec.Result().Body)
		if err != nil {
			t.Errorf("reading rendered %s: %v", tc.name, err)
			continue
		}
		if len(body) == 0 {
			t.Errorf("rendering %s produced an empty body", tc.name)
		}
	}
}
