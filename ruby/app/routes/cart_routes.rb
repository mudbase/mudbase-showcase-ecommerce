# frozen_string_literal: true

# Cart: one `carts` document per user, read-then-create-or-update (no native upsert - see
# CartsRepo). Every mutation re-derives price/name/currency from the current product record
# server-side rather than trusting the submitted form fields - a hidden `price_cents` input
# would otherwise let a shopper check out at any price they choose.
class App < Sinatra::Base
  get "/cart" do
    require_login!

    @items = with_access_token { |token| Mudbase::CartsRepo.items_for_user(access_token: token, user_id: @current_user[:id]) }
    @subtotal_cents = Mudbase::CartsRepo.subtotal_cents(@items)

    erb :"cart/index"
  end

  post "/cart/add" do
    require_login!

    product = with_access_token { |token| Mudbase::ProductsRepo.find(access_token: token, id: params["product_id"]) }
    halt 404, "Product not found" unless product

    quantity = [params["quantity"].to_i, 1].max
    quantity = [quantity, product[:stock]].min if product[:stock].to_i.positive?

    with_access_token do |token|
      Mudbase::CartsRepo.add_item!(
        access_token: token,
        user_id: @current_user[:id],
        item: {
          productId: product[:_id],
          name: product[:name],
          priceCents: product[:priceCents],
          currency: product[:currency],
          imageUrl: product[:imageUrl],
          quantity: quantity,
        },
      )
    end

    flash_notice("Added #{product[:name]} to your cart.")
    redirect "/products/#{product[:slug]}"
  end

  post "/cart/update" do
    require_login!

    with_access_token do |token|
      Mudbase::CartsRepo.update_quantity!(
        access_token: token,
        user_id: @current_user[:id],
        product_id: params["product_id"],
        quantity: params["quantity"].to_i,
      )
    end

    redirect "/cart"
  end

  post "/cart/remove" do
    require_login!

    with_access_token do |token|
      Mudbase::CartsRepo.remove_item!(
        access_token: token,
        user_id: @current_user[:id],
        product_id: params["product_id"],
      )
    end

    redirect "/cart"
  end
end
