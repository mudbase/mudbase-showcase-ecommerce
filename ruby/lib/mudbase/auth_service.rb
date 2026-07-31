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
      request = MudbaseSDK::RegisterWithRoleRequest.new(
        email: email,
        password: password,
        first_name: first_name,
        last_name: last_name,
        project_id: Mudbase::Config.project_id,
      )

      # `RegisterWithRoleRequest` doesn't declare `agreedToTerms` (the generator only typed
      # the fields in its schema), but the platform's signup validator rejects the request
      # without it - confirmed by the reference web app's own `/api/auth/local/signup/:role`
      # caller. `debug_body` overrides the serialized request body so this field still goes
      # out on the wire even though the typed model can't carry it.
      body_json = {
        email: email,
        password: password,
        firstName: first_name,
        lastName: last_name,
        projectId: Mudbase::Config.project_id,
        agreedToTerms: agreed_to_terms,
      }.to_json

      data, = Mudbase::ClientFactory.multi_role_api.register_with_role_with_http_info(
        CUSTOMER_ROLE,
        request,
        debug_return_type: "Object",
        debug_body: body_json,
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
