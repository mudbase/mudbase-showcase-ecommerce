# frozen_string_literal: true

require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `products` (public read for any signed-in role; `seller` role
  # full CRUD). All list/get/create/update calls force `debug_return_type: "Object"` (see
  # ClientFactory) so every real document field survives - the generated
  # `DataListResponseDataInner` model only types `_id`/`created_at`/`updated_at`.
  module ProductsRepo
    def self.list(access_token:, category: nil, active_only: true)
      filter = {}
      filter["isActive"] = true if active_only
      filter["category"] = category if category && !category.empty?

      opts = { sort: "-createdAt", limit: 100 }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      opts[:filter] = filter.to_json unless filter.empty?

      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.products_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.find_by_slug(access_token:, slug:)
      opts = { filter: { slug: slug }.to_json, limit: 1 }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.products_collection_id,
        opts,
      )
      (data[:data] || []).first
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.products_collection_id,
        id,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    rescue MudbaseSDK::ApiError
      nil
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.products_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.products_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.categories(products)
      products.filter_map { |p| p[:category] }.reject(&:empty?).uniq.sort
    end
  end
end
