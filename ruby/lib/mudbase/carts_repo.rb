# frozen_string_literal: true

require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"
require_relative "json_field"

module Mudbase
  # `carts`: one document per user, `customer` role full CRUD scoped to `{ userId: "$userId" }`.
  # Mudbase Collections have no native upsert endpoint, so every write here is a
  # read-then-create-or-update - same pattern as the reference app's `useCart` hook,
  # including re-reading right before deciding create-vs-update rather than trusting any
  # value that might already be stale by the time the write happens.
  module CartsRepo
    def self.find_for_user(access_token:, user_id:)
      opts = { filter: { userId: user_id }.to_json, limit: 1 }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.carts_collection_id,
        opts,
      )
      (data[:data] || []).first
    end

    def self.items_for_user(access_token:, user_id:)
      cart = find_for_user(access_token: access_token, user_id: user_id)
      return [] unless cart

      Mudbase::JsonField.parse(cart[:itemsJson], [])
    end

    # @param items [Array<Hash>] each with symbol keys productId/name/priceCents/currency/
    #   imageUrl/quantity - persisted as a JSON string in `itemsJson`.
    def self.save_items!(access_token:, user_id:, items:)
      existing = find_for_user(access_token: access_token, user_id: user_id)
      items_json = Mudbase::JsonField.stringify(items)
      api = Mudbase::ClientFactory.data_api(access_token: access_token)

      if existing
        data, = api.update_data_with_http_info(
          Mudbase::Config.project_id,
          Mudbase::Config.carts_collection_id,
          existing[:_id],
          { itemsJson: items_json },
          Mudbase::ClientFactory::OBJECT_RESPONSE,
        )
      else
        data, = api.create_data_with_http_info(
          Mudbase::Config.project_id,
          Mudbase::Config.carts_collection_id,
          { userId: user_id, itemsJson: items_json },
          Mudbase::ClientFactory::OBJECT_RESPONSE,
        )
      end
      data[:data]
    end

    def self.add_item!(access_token:, user_id:, item:)
      items = items_for_user(access_token: access_token, user_id: user_id)
      existing_index = items.index { |i| i[:productId] == item[:productId] }

      if existing_index
        items[existing_index] = items[existing_index].merge(
          quantity: items[existing_index][:quantity] + item[:quantity],
        )
      else
        items << item
      end

      save_items!(access_token: access_token, user_id: user_id, items: items)
    end

    def self.update_quantity!(access_token:, user_id:, product_id:, quantity:)
      items = items_for_user(access_token: access_token, user_id: user_id)
      next_items = if quantity <= 0
        items.reject { |i| i[:productId] == product_id }
      else
        items.map { |i| i[:productId] == product_id ? i.merge(quantity: quantity) : i }
      end
      save_items!(access_token: access_token, user_id: user_id, items: next_items)
    end

    def self.remove_item!(access_token:, user_id:, product_id:)
      items = items_for_user(access_token: access_token, user_id: user_id).reject { |i| i[:productId] == product_id }
      save_items!(access_token: access_token, user_id: user_id, items: items)
    end

    def self.clear!(access_token:, user_id:)
      save_items!(access_token: access_token, user_id: user_id, items: [])
    end

    def self.subtotal_cents(items)
      items.sum { |i| i[:priceCents] * i[:quantity] }
    end
  end
end
