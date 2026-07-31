# frozen_string_literal: true

require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # `orders`: `customer` role can create/read/update only its own (`{ userId: "$userId" }`);
  # `seller` role can read/update all (the fulfillment queue). The status field is named
  # `orderStatus`, not `status` - Mudbase's server-side role-assignment guard
  # (`enforceServerRoleAssignment.js`) blocks any collection write containing a literal
  # `status` key for every project end-user regardless of role or collection permissions.
  # This is a real platform constraint, confirmed against the reference Next.js app's own
  # `orders` collection - see README "Known limitations".
  module OrdersRepo
    def self.list_for_user(access_token:, user_id:)
      opts = { filter: { userId: user_id }.to_json, sort: "-createdAt", limit: 100 }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.orders_collection_id,
        opts,
      )
      data[:data] || []
    end

    # Seller fulfillment queue - unrestricted by the `seller` role's collection permissions.
    def self.list_all(access_token:)
      opts = { sort: "-createdAt", limit: 100 }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.orders_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.orders_collection_id,
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
        Mudbase::Config.orders_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.orders_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    NEXT_STATUS = { "paid" => "shipped", "shipped" => "delivered" }.freeze

    def self.next_status_for(order_status)
      NEXT_STATUS[order_status]
    end
  end
end
