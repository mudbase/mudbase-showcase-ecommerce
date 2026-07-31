# frozen_string_literal: true

require_relative "mudbase/errors"
require_relative "mudbase/auth_service"

# Sinatra helpers for reading/writing the signed-in user's state. The Mudbase-issued JWT is
# held only inside the Rack session cookie (encrypted + signed + httponly via
# Rack::Session::Cookie, configured in app.rb) - it is never rendered into a page or exposed to
# client-side JavaScript.
#
# Refresh-token rotation: `current_user`/`logged_in?` are keyed only on whether a user was ever
# stored in this session - NOT on the tracked access-token expiry - because the access token is
# independently recoverable via `with_access_token` below. Every route that calls Mudbase must
# route the access token through `with_access_token { |token| ... }` instead of reading
# `access_token` directly: it proactively refreshes a token that's about to expire, and - the
# same as the reference Next.js app's `MudbaseClient#request` - reactively refreshes and retries
# exactly once on a real 401 from the server. Only when the refresh token itself is rejected
# (expired/already rotated away/revoked) does the session actually get torn down, via
# `MudbaseSDK::ApiError` bubbling up to app.rb's global 401 handler, which calls
# `clear_auth_session!` and redirects to `/login`.
module SessionHelpers
  TOKEN_REFRESH_MARGIN_SECONDS = 60

  def store_auth_session!(auth_session)
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    session[:user] = auth_session.user
  end

  def clear_auth_session!
    session.clear
  end

  def access_token
    session[:token]
  end

  def current_user
    session[:user]
  end

  def logged_in?
    !current_user.nil?
  end

  # Wraps every Mudbase call that needs the signed-in user's access token. Proactively refreshes
  # a token that's within `TOKEN_REFRESH_MARGIN_SECONDS` of its tracked expiry (avoids a wasted
  # round trip most of the time), then - if the call still comes back with a real 401 (clock
  # drift, a token revoked server-side, etc.) - refreshes once more and retries the block exactly
  # once. If no refresh token is stored, or the refresh token itself is rejected, the original
  # `MudbaseSDK::ApiError` propagates to app.rb's global handler, which logs the session out.
  def with_access_token
    refresh_access_token! if token_expiring_soon?
    yield session[:token]
  rescue MudbaseSDK::ApiError => e
    failure = Mudbase::ApiFailure.from(e)
    raise e unless failure.status == 401
    raise e unless refresh_access_token!

    yield session[:token]
  end

  def token_expiring_soon?
    session[:expires_at].nil? || Time.now.to_i >= session[:expires_at] - TOKEN_REFRESH_MARGIN_SECONDS
  end

  # @return [Boolean] whether the refresh succeeded and `session[:token]` is now fresh.
  def refresh_access_token!
    return false unless session[:refresh_token]

    auth_session = Mudbase::AuthService.refresh!(session[:refresh_token])
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    true
  rescue Mudbase::AuthError
    false
  end

  def seller?
    current_user && current_user[:customRole] == "seller"
  end

  def customer?
    current_user && current_user[:customRole] == "customer"
  end

  def require_login!
    return if logged_in?

    session[:return_to] = request.path_info
    redirect "/login"
  end

  def require_seller!
    require_login!
    return if seller?

    flash_error("That area is for sellers only.")
    redirect "/"
  end

  def consume_return_to
    session.delete(:return_to) || "/"
  end

  # For "set then redirect" flows: written to the session so the *next* request's `before`
  # filter (which runs before the route body, and so before any `flash_error`/`flash_notice`
  # call made this request) can pick it up via pop_flash_notice/pop_flash_error.
  def flash_notice(message)
    session[:flash_notice] = message
  end

  def flash_error(message)
    session[:flash_error] = message
  end

  def pop_flash_notice
    session.delete(:flash_notice)
  end

  def pop_flash_error
    session.delete(:flash_error)
  end

  # For "validate, then re-render the same page in this same response" flows (a failed
  # login/register/checkout/product form). `@flash_error`/`@flash_notice` are already
  # populated for this request by the `before` filter *before* the route body runs, so a
  # form-validation failure has to set the ivar directly - writing to session here would
  # only become visible on the *following* request, leaving this response's re-rendered form
  # with no visible error at all.
  def show_error_now(message)
    @flash_error = message
  end

  def show_notice_now(message)
    @flash_notice = message
  end
end
