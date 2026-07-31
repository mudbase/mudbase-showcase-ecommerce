# frozen_string_literal: true

module Mudbase
  # Fails fast at boot with a clear message rather than surfacing a confusing
  # nil-related error deep inside a request handler later.
  class MissingEnvError < StandardError
    def initialize(name)
      super("Missing required environment variable: #{name}")
    end
  end

  module Config
    def self.require_env(name)
      value = ENV[name]
      raise MissingEnvError, name if value.nil? || value.empty?

      value
    end

    def self.base_url
      ENV.fetch("MUDBASE_URL", "https://cloud.mudbase.dev")
    end

    def self.project_id
      require_env("MUDBASE_PROJECT_ID")
    end

    def self.products_collection_id
      require_env("PRODUCTS_COLLECTION_ID")
    end

    def self.orders_collection_id
      require_env("ORDERS_COLLECTION_ID")
    end

    def self.carts_collection_id
      require_env("CARTS_COLLECTION_ID")
    end

    def self.session_secret
      require_env("SESSION_SECRET")
    end

    def self.pay_link_proxy_url
      require_env("PAY_LINK_PROXY_URL")
    end

    def self.app_base_url
      ENV.fetch("APP_BASE_URL", "http://localhost:4567")
    end
  end
end
