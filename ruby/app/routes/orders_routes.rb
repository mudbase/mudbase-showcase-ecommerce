# frozen_string_literal: true

# Order history + detail. Ownership is enforced server-side by Mudbase's
# `{ userId: "$userId" }` collection-permission condition on the `orders` collection for the
# `customer` role (the `seller` role can read any order, for the fulfillment queue) - this app
# doesn't re-implement that check client-side, it just renders whatever Mudbase returns for the
# caller's own token, per "authorization is enforced server-side by collection permissions."
class App < Sinatra::Base
  get "/orders" do
    require_login!

    @orders = Mudbase::OrdersRepo.list_for_user(access_token: access_token, user_id: @current_user[:id])
    erb :"orders/index"
  end

  get "/orders/:id" do
    require_login!

    @order = Mudbase::OrdersRepo.find(access_token: access_token, id: params["id"])
    halt 404, erb(:"errors/not_found", layout: :layout) unless @order

    @items = Mudbase::JsonField.parse(@order[:itemsJson], [])
    @address = Mudbase::JsonField.parse(@order[:shippingAddressJson], nil)
    erb :"orders/show"
  end
end
