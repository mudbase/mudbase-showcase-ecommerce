# frozen_string_literal: true

require "securerandom"

# Seller area: product list/create/edit and the order fulfillment queue. Gated on
# `customRole == "seller"` client-side for UX (the real authorization boundary is Mudbase's
# collection permissions - `seller` role has unconditional CRUD on `products` and
# unconditional read/update on `orders`, `customer` role has neither).
class App < Sinatra::Base
  get "/seller" do
    require_seller!

    @orders = with_access_token { |token| Mudbase::OrdersRepo.list_all(access_token: token) }
    @products = with_access_token { |token| Mudbase::ProductsRepo.list(access_token: token, active_only: false) }
    erb :"seller/dashboard"
  end

  get "/seller/products/new" do
    require_seller!

    @product = default_product_form_values
    @form_action = "/seller/products"
    @form_title = "Add product"
    erb :"seller/product_form"
  end

  post "/seller/products" do
    require_seller!

    values = extract_product_form(params)
    errors = validate_product_form(values)
    if errors.any?
      @product = values
      @form_action = "/seller/products"
      @form_title = "Add product"
      show_error_now(errors.join(" "))
      halt erb(:"seller/product_form")
    end

    slug = "#{slugify(values[:name])}-#{SecureRandom.alphanumeric(6).downcase}"
    with_access_token do |token|
      Mudbase::ProductsRepo.create!(
        access_token: token,
        attributes: product_attributes(values).merge(slug: slug, sellerId: @current_user[:id]),
      )
    end

    flash_notice("#{values[:name]} was added to the catalog.")
    redirect "/seller"
  end

  get "/seller/products/:id/edit" do
    require_seller!

    product = with_access_token { |token| Mudbase::ProductsRepo.find(access_token: token, id: params["id"]) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless product

    @product = product_to_form_values(product)
    @form_action = "/seller/products/#{product[:_id]}"
    @form_title = "Edit product"
    erb :"seller/product_form"
  end

  post "/seller/products/:id" do
    require_seller!

    values = extract_product_form(params)
    errors = validate_product_form(values)
    if errors.any?
      @product = values
      @form_action = "/seller/products/#{params['id']}"
      @form_title = "Edit product"
      show_error_now(errors.join(" "))
      halt erb(:"seller/product_form")
    end

    with_access_token do |token|
      Mudbase::ProductsRepo.update!(
        access_token: token,
        id: params["id"],
        attributes: product_attributes(values),
      )
    end

    flash_notice("#{values[:name]} was updated.")
    redirect "/seller"
  end

  post "/seller/orders/:id/status" do
    require_seller!

    order = with_access_token { |token| Mudbase::OrdersRepo.find(access_token: token, id: params["id"]) }
    halt 404, "Order not found" unless order

    next_status = Mudbase::OrdersRepo.next_status_for(order[:orderStatus])
    if next_status
      with_access_token { |token| Mudbase::OrdersRepo.update!(access_token: token, id: order[:_id], attributes: { orderStatus: next_status }) }
      flash_notice("Order marked #{next_status}.")
    end

    redirect "/seller"
  end

  helpers do
    GALLERY_URL_LIMIT = 8

    def default_product_form_values
      { name: "", description: "", price_cents: 0, compare_at_price_cents: "", currency: "USD",
        image_url: "", gallery_urls: [], category: "", stock: 0, is_active: true }
    end

    def extract_product_form(params)
      gallery_urls = (params["gallery_urls"] || "").to_s.split("\n").map(&:strip).reject(&:empty?).first(GALLERY_URL_LIMIT)
      {
        name: params["name"].to_s.strip,
        description: params["description"].to_s.strip,
        price_cents: params["price_cents"].to_i,
        compare_at_price_cents: params["compare_at_price_cents"].to_s.strip,
        currency: (params["currency"].to_s.strip.empty? ? "USD" : params["currency"].to_s.strip),
        image_url: params["image_url"].to_s.strip,
        gallery_urls: gallery_urls,
        category: params["category"].to_s.strip,
        stock: params["stock"].to_i,
        is_active: params["is_active"] == "1",
      }
    end

    def product_to_form_values(product)
      {
        name: product[:name], description: product[:description].to_s,
        price_cents: product[:priceCents], compare_at_price_cents: product[:compareAtPriceCents]&.to_s || "",
        currency: product[:currency], image_url: product[:imageUrl].to_s,
        gallery_urls: Mudbase::JsonField.parse(product[:galleryJson], []),
        category: product[:category].to_s, stock: product[:stock], is_active: product[:isActive],
      }
    end

    def validate_product_form(values)
      errors = []
      errors << "Name is required." if values[:name].empty?
      errors << "Price can't be negative." if values[:price_cents].negative?
      errors << "Stock can't be negative." if values[:stock].negative?
      unless values[:compare_at_price_cents].empty?
        compare_at = values[:compare_at_price_cents].to_i
        errors << "Compare-at price must be higher than the current price." if compare_at <= values[:price_cents]
      end
      values[:gallery_urls].each do |url|
        errors << "\"#{url}\" doesn't look like a valid URL." unless url.match?(%r{\Ahttps?://})
      end
      unless values[:image_url].empty? || values[:image_url].match?(%r{\Ahttps?://})
        errors << "Main image URL must start with http:// or https://."
      end
      errors
    end

    def product_attributes(values)
      attrs = {
        name: values[:name],
        description: values[:description],
        priceCents: values[:price_cents],
        currency: values[:currency],
        imageUrl: values[:image_url].empty? ? nil : values[:image_url],
        galleryJson: Mudbase::JsonField.stringify(values[:gallery_urls]),
        category: values[:category],
        stock: values[:stock],
        isActive: values[:is_active],
      }
      attrs[:compareAtPriceCents] = values[:compare_at_price_cents].to_i unless values[:compare_at_price_cents].empty?
      attrs
    end
  end
end
