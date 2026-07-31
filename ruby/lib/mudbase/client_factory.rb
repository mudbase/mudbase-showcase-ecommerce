# frozen_string_literal: true

require "mudbase_sdk"
require_relative "config"

module Mudbase
  # Builds a fresh, request-scoped set of generated `MudbaseSDK::*Api` instances.
  #
  # `MudbaseSDK::Configuration.default` / `MudbaseSDK::ApiClient.default` are process-wide
  # singletons - every generated API class defaults to them (`def initialize(api_client =
  # ApiClient.default)`). Calling the documented `MudbaseSDK.configure { |c| c.access_token
  # = jwt }` per request would mutate that shared singleton, which is a real race condition
  # in a multi-threaded/multi-worker Sinatra server: request A could read request B's bearer
  # token if both configure the global default concurrently. Instead, every call site in this
  # app builds its own `Configuration.new` + `ApiClient.new(config)` and hands the resulting
  # api_client explicitly into `AuthenticationApi.new(api_client)` /
  # `DataApi.new(api_client)` / `MultiRoleFeatureApi.new(api_client)` - fully isolated per
  # request, no shared mutable state.
  module ClientFactory
    # @param access_token [String, nil] Mudbase-issued JWT for the signed-in end-user.
    #   Omit for public endpoints (login, register, anonymous browsing of public data).
    # @return [MudbaseSDK::ApiClient]
    def self.api_client(access_token: nil)
      config = MudbaseSDK::Configuration.new
      config.host = URI.parse(Mudbase::Config.base_url).host
      config.scheme = URI.parse(Mudbase::Config.base_url).scheme
      config.access_token = access_token if access_token
      MudbaseSDK::ApiClient.new(config)
    end

    def self.auth_api(access_token: nil)
      MudbaseSDK::AuthenticationApi.new(api_client(access_token: access_token))
    end

    def self.multi_role_api(access_token: nil)
      MudbaseSDK::MultiRoleFeatureApi.new(api_client(access_token: access_token))
    end

    def self.data_api(access_token: nil)
      MudbaseSDK::DataApi.new(api_client(access_token: access_token))
    end

    # Forces the generated `_with_http_info` wrapper to deserialize the response body as a
    # plain Hash instead of a typed model. Needed everywhere in this app because:
    #
    #   1. `DataListResponseDataInner`/similar collection-document models only declare
    #      `_id`/`created_at`/`updated_at` (Collections are a dynamic per-project schema
    #      the generator can't type) - every real field (name, priceCents, itemsJson, ...)
    #      would be silently dropped by typed deserialization.
    #   2. `User`/`LoginLocalUser200ResponseUser`/`CreateAnonymousSession200ResponseUser`
    #      do not declare `customRole` or `isAnonymous`, even though the real API returns
    #      them (confirmed against the reference Next.js app's own `UserObject` type) -
    #      this app's seller-area gating depends on `customRole`, so it cannot be lost.
    #   3. `MultiRoleFeatureApi#register_with_role` is generated with return type `nil`
    #      (the wrapper hardcodes `return_type = opts[:debug_return_type]`, which is nil
    #      unless a caller supplies it) - without this override the signup response (token,
    #      user) would be discarded entirely, even though the server actually returns it.
    #
    # `debug_return_type`/`debug_body` are documented escape hatches baked into every
    # openapi-generator Ruby client's generated methods (see any `_with_http_info` method
    # body) - using them here is a deliberate, narrow workaround for the three real model
    # gaps above, not a hack around the transport layer itself.
    OBJECT_RESPONSE = { debug_return_type: "Object" }.freeze
  end
end
