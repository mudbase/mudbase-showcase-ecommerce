# frozen_string_literal: true

require "json"

# Checkout: shipping form -> creates an `orders` document (awaiting_payment) -> calls the
# payment-link proxy on the reference web app -> redirects to a payment status page that polls
# the public payment-link endpoint until paid/expired. Everything before the payment-link call
# happens under the shopper's own Mudbase session; the payment-link call itself is delegated
# (see PaymentLinkClient for why).
class App < Sinatra::Base
  SHIPPING_FIELDS = %w[full_name line1 line2 city region postal_code country].freeze
  CHECKOUT_CURRENCY = "USDC"
  CHECKOUT_NETWORK = "POLYGON"

  get "/checkout" do
    require_login!

    @items = with_access_token { |token| Mudbase::CartsRepo.items_for_user(access_token: token, user_id: @current_user[:id]) }
    if @items.empty?
      flash_error("Your cart is empty - add something before checking out.")
      redirect "/cart"
    end

    @subtotal_cents = Mudbase::CartsRepo.subtotal_cents(@items)
    @shipping = default_shipping_values
    erb :"checkout/shipping"
  end

  post "/checkout" do
    require_login!

    items = with_access_token { |token| Mudbase::CartsRepo.items_for_user(access_token: token, user_id: @current_user[:id]) }
    if items.empty?
      flash_error("Your cart is empty - add something before checking out.")
      redirect "/cart"
    end

    @shipping = SHIPPING_FIELDS.to_h { |f| [f, params[f].to_s.strip] }
    errors = validate_shipping(@shipping)
    if errors.any?
      @items = items
      @subtotal_cents = Mudbase::CartsRepo.subtotal_cents(items)
      show_error_now(errors.join(" "))
      halt erb(:"checkout/shipping")
    end

    subtotal_cents = Mudbase::CartsRepo.subtotal_cents(items)
    shipping_address = {
      fullName: @shipping["full_name"],
      line1: @shipping["line1"],
      line2: @shipping["line2"],
      city: @shipping["city"],
      region: @shipping["region"],
      postalCode: @shipping["postal_code"],
      country: @shipping["country"],
    }

    order = with_access_token do |token|
      Mudbase::OrdersRepo.create!(
        access_token: token,
        attributes: {
          userId: @current_user[:id],
          itemsJson: Mudbase::JsonField.stringify(
            items.map { |i| { productId: i[:productId], name: i[:name], priceCents: i[:priceCents], quantity: i[:quantity] } },
          ),
          subtotalCents: subtotal_cents,
          currency: "USD",
          orderStatus: "awaiting_payment",
          shippingName: shipping_address[:fullName],
          shippingAddressJson: Mudbase::JsonField.stringify(shipping_address),
          paymentStatus: "unpaid",
        },
      )
    end

    amount = format("%.2f", subtotal_cents / 100.0)
    result = Mudbase::PaymentLinkClient.create_for_order(
      order_id: order[:_id],
      amount: amount,
      currency: CHECKOUT_CURRENCY,
      network: CHECKOUT_NETWORK,
    )

    unless result.ok?
      if result.kyc_required?
        with_access_token { |token| Mudbase::OrdersRepo.update!(access_token: token, id: order[:_id], attributes: { orderStatus: "pending" }) }
        flash_error(result.error_message)
      else
        flash_error(result.error_message)
      end
      redirect "/orders/#{order[:_id]}"
    end

    with_access_token do |token|
      Mudbase::OrdersRepo.update!(
        access_token: token,
        id: order[:_id],
        attributes: { paymentLinkToken: result.link[:token] },
      )
    end
    with_access_token { |token| Mudbase::CartsRepo.clear!(access_token: token, user_id: @current_user[:id]) }

    redirect "/checkout/#{result.link[:token]}"
  end

  get "/checkout/:token" do
    @token = params["token"]
    erb :"checkout/pay"
  end

  # Server-side proxy for the client-side poller in checkout/pay.erb - avoids relying on
  # cloud.mudbase.dev's CORS policy being open to arbitrary browser origins for a page that
  # otherwise has no other server round-trip once rendered.
  get "/checkout/:token/status.json" do
    content_type :json
    link = Mudbase::PaymentLinkClient.public_status(params["token"])
    halt 404 unless link

    link.to_json
  end

  helpers do
    def default_shipping_values
      SHIPPING_FIELDS.to_h { |f| [f, ""] }
    end

    def validate_shipping(shipping)
      errors = []
      errors << "Full name is required." if shipping["full_name"].empty?
      errors << "Address is required." if shipping["line1"].empty?
      errors << "City is required." if shipping["city"].empty?
      errors << "State/region is required." if shipping["region"].empty?
      errors << "Postal code is required." if shipping["postal_code"].empty?
      errors << "Country is required." if shipping["country"].empty?
      errors
    end
  end
end
