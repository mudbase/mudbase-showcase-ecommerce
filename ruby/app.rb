# frozen_string_literal: true

require "dotenv/load"
require "uri"
require "sinatra/base"

require_relative "lib/mudbase/config"
require_relative "lib/mudbase/client_factory"
require_relative "lib/mudbase/json_field"
require_relative "lib/mudbase/errors"
require_relative "lib/mudbase/auth_service"
require_relative "lib/mudbase/products_repo"
require_relative "lib/mudbase/carts_repo"
require_relative "lib/mudbase/orders_repo"
require_relative "lib/mudbase/payment_link_client"
require_relative "lib/session_helpers"
require_relative "lib/view_helpers"

# Commonwealth Goods - a production storefront built entirely on Mudbase (auth, database,
# payments), rendered server-side with Sinatra + ERB. This is one of several per-language
# reimplementations of the same reference storefront (see the companion Next.js app under
# ../web) - same collections, same field shapes, same payment-link delegation, different stack.
class App < Sinatra::Base
  configure do
    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, "views")
    set :public_folder, File.join(settings.root, "public")
    set :show_exceptions, false
    set :raise_errors, false

    is_production = ENV.fetch("RACK_ENV", "development") == "production"
    set :session_secret, Mudbase::Config.session_secret
    set :sessions, {
      key: "mudbase_showcase.session",
      httponly: true,
      same_site: :lax,
      secure: is_production,
      expire_after: 60 * 60 * 12,
    }
  end

  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  helpers SessionHelpers
  helpers ViewHelpers

  before do
    @flash_notice = pop_flash_notice
    @flash_error = pop_flash_error
    @current_user = current_user
    @cart_count = if @current_user
      with_access_token { |token| Mudbase::CartsRepo.items_for_user(access_token: token, user_id: @current_user[:id]) }
        .sum { |i| i[:quantity] }
    end
  end

  # `MudbaseSDK::ApiError` is what every generated API call raises on a non-2xx response
  # (invalid input, expired token, permission denial, etc.) - surfaced here as a flash-style
  # error banner instead of a raw 500, matching "never silently swallow errors" while still
  # giving the shopper something actionable.
  error MudbaseSDK::ApiError do
    failure = Mudbase::ApiFailure.from(env["sinatra.error"])
    if failure.status == 401
      clear_auth_session!
      flash_error("Your session expired - please sign in again.")
      redirect "/login"
    else
      flash_error(failure.friendly_message)
      redirect back_or("/")
    end
  end

  error Mudbase::MissingEnvError do
    content_type :text
    status 500
    "Server misconfigured: #{env['sinatra.error'].message}"
  end

  # Sinatra routes every 404 - including an explicit `halt 404` from inside a route, like the
  # payment-status JSON poller - through this single handler, so it has to stay format-aware
  # rather than always rendering the HTML error page.
  not_found do
    if request.path_info.end_with?(".json")
      content_type :json
      { error: "Not found" }.to_json
    else
      erb :"errors/not_found", layout: :layout
    end
  end

  error do
    logger.error(env["sinatra.error"]&.full_message) if env["sinatra.error"]
    erb :"errors/server_error", layout: :layout
  end

  helpers do
    def back_or(default_path)
      request.referrer && URI.parse(request.referrer).path != request.path ? request.referrer : default_path
    rescue URI::InvalidURIError
      default_path
    end
  end
end

require_relative "app/routes/catalog_routes"
require_relative "app/routes/cart_routes"
require_relative "app/routes/auth_routes"
require_relative "app/routes/checkout_routes"
require_relative "app/routes/orders_routes"
require_relative "app/routes/seller_routes"
