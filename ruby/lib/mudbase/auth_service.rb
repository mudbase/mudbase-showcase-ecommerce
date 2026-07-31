# frozen_string_literal: true

require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"
require_relative "errors"

module Mudbase
  # Raised for any login/register failure the caller should show to the end user.
  class AuthError < StandardError
    def initialize(message, requires_verification: false)
      super(message)
      @requires_verification = requires_verification
    end

    def requires_verification?
      @requires_verification
    end
  end

  # Normalizes the raw parsed-JSON auth response (token/refreshToken/expiresIn/user) into a
  # small value object the session helpers can store. Field names stay camelCase-symbol,
  # matching the wire format exactly (see ClientFactory::OBJECT_RESPONSE for why this app reads
  # raw hashes here instead of the generated typed models).
  AuthSession = Struct.new(:token, :refresh_token, :expires_in, :user, keyword_init: true) do
    def self.from_hash(data)
      new(
        token: data[:token],
        refresh_token: data[:refreshToken],
        expires_in: data[:expiresIn] || 3600,
        user: data[:user] || {},
      )
    end
  end

  # Wraps `MudbaseSDK::MultiRoleFeatureApi#register_with_role` and
  # `MudbaseSDK::AuthenticationApi#login_local_user` - the only two auth flows this app needs
  # (role is always "customer" for self-signup; seller accounts are provisioned out-of-band,
  # same limitation the reference Next.js app documents - there is no self-service
  # "become a seller" flow here either).
  module AuthService
    CUSTOMER_ROLE = "customer"

    def self.register_customer!(email:, password:, first_name:, last_name:, agreed_to_terms:)
      # Post-regen: `RegisterWithRoleRequest` now declares `agreed_to_terms` natively (wire key
      # `agreedToTerms`) and its setter only rejects `nil`, so passing the real boolean is
      # sufficient - the old `debug_body:` JSON-override hack for this field is gone. This call
      # still forces `debug_return_type: "Object"` (not because the wire response is untyped
      # anymore - `RegisterWithRole201Response`/`RegisterWithRole201ResponseUser` are now
      # generated with `token`/`refreshToken`/`expiresIn`/`customRole` etc. - but purely so
      # `handle_auth_response` can share one Hash-shaped code path with `login!`, whose
      # `LoginLocalUser200ResponseUser` still doesn't declare `customRole` at all (see
      # ClientFactory::OBJECT_RESPONSE). Two different parsing paths for the same
      # AuthSession#user shape would be its own source of bugs.
      request = MudbaseSDK::RegisterWithRoleRequest.new(
        email: email,
        password: password,
        first_name: first_name,
        last_name: last_name,
        project_id: Mudbase::Config.project_id,
        agreed_to_terms: agreed_to_terms,
      )

      data, = Mudbase::ClientFactory.multi_role_api.register_with_role_with_http_info(
        CUSTOMER_ROLE,
        request,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )

      handle_auth_response(data)
    rescue MudbaseSDK::ApiError => e
      raise AuthError, Mudbase::ApiFailure.from(e).friendly_message
    end

    def self.login!(email:, password:)
      request = MudbaseSDK::LoginLocalUserRequest.new(
        email: email,
        password: password,
        project_id: Mudbase::Config.project_id,
      )

      data, = Mudbase::ClientFactory.auth_api.login_local_user_with_http_info(
        request,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )

      handle_auth_response(data)
    rescue MudbaseSDK::ApiError => e
      failure = Mudbase::ApiFailure.from(e)
      if failure.status == 403
        raise AuthError.new(failure.friendly_message, requires_verification: true)
      end

      raise AuthError, failure.friendly_message
    end

    # Exchanges a stored (single-use, rotate-on-use) refresh token for a fresh access/refresh
    # pair. `RefreshToken200Response` (message/token/refreshToken/expiresIn) has no dynamic
    # per-project fields and no nested user model, so it doesn't hit either of the typed-model
    # gaps `OBJECT_RESPONSE` exists for - the plain typed response is used as-is. No `user` in
    # the response (the identity doesn't change on refresh), so the returned `AuthSession#user`
    # is left `nil`; callers that only need the refreshed token/expiry (see
    # SessionHelpers#refresh_access_token!) don't touch it.
    def self.refresh!(refresh_token)
      request = MudbaseSDK::RefreshTokenRequest.new(refresh_token: refresh_token)
      data, = Mudbase::ClientFactory.auth_api.refresh_token_with_http_info(request)

      AuthSession.new(
        token: data.token,
        refresh_token: data.refresh_token,
        expires_in: data.expires_in || 3600,
        user: nil,
      )
    rescue MudbaseSDK::ApiError => e
      raise AuthError, Mudbase::ApiFailure.from(e).friendly_message
    end

    def self.logout!(access_token)
      Mudbase::ClientFactory.auth_api(access_token: access_token).logout_local_user
    rescue MudbaseSDK::ApiError
      # Best-effort: the local session cookie is cleared by the caller regardless, so a
      # failed server-side revoke (expired token, network blip) shouldn't block sign-out.
      nil
    end

    def self.handle_auth_response(data)
      if data[:token].nil? && data[:requireVerification]
        raise AuthError.new(
          "Account created - check your email to verify it, then sign in.",
          requires_verification: true,
        )
      end

      AuthSession.from_hash(data)
    end
    private_class_method :handle_auth_response
  end
end
