# frozen_string_literal: true

# Product catalog (list + category filter) and product detail. The `products` collection
# grants read access to the `authenticated` role only (see README "Known limitations" for why
# that means no anonymous browsing in this reimplementation), so both routes require login.
class App < Sinatra::Base
  get "/" do
    require_login!

    @selected_category = params["category"].to_s.strip
    @selected_category = nil if @selected_category.empty?

    all_active = Mudbase::ProductsRepo.list(access_token: access_token, active_only: true)
    @categories = Mudbase::ProductsRepo.categories(all_active)
    @products = @selected_category ? all_active.select { |p| p[:category] == @selected_category } : all_active

    erb :"catalog/index"
  end

  get "/products/:slug" do
    require_login!

    @product = Mudbase::ProductsRepo.find_by_slug(access_token: access_token, slug: params["slug"])
    halt 404, erb(:"errors/not_found", layout: :layout) unless @product

    @gallery = [@product[:imageUrl], *Mudbase::JsonField.parse(@product[:galleryJson], [])].compact
    @discount_percent = discount_percent(@product[:priceCents], @product[:compareAtPriceCents])

    erb :"catalog/show"
  end
end
