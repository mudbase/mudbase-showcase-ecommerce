# frozen_string_literal: true

# Sinatra helpers for reading/writing the signed-in user's state. The Mudbase-issued JWT is
# held only inside the Rack session cookie (encrypted + signed + httponly via
# Rack::Session::Cookie, configured in app.rb) - it is never rendered into a page or exposed to
# client-side JavaScript. This app doesn't implement refresh-token rotation: once the JWT's
# lifetime (tracked via `expires_at`) elapses, `current_user` treats the session as logged out
# and the next Mudbase call that would have needed auth instead redirects to /login. That's a
# deliberate scope cut for a reference/demo app - see README "Known limitations".
module SessionHelpers
  def store_auth_session!(auth_session)
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    session[:user] = auth_session.user
  end

  def clear_auth_session!
    session.clear
  end

  def session_expired?
    session[:expires_at].nil? || Time.now.to_i >= session[:expires_at]
  end

  def access_token
    return nil if session_expired?

    session[:token]
  end

  def current_user
    return nil if session_expired?

    session[:user]
  end

  def logged_in?
    !current_user.nil?
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
