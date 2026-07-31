# frozen_string_literal: true

require "json"

module Mudbase
  # Mudbase Collection fields have a fixed type enum (string, number, boolean, date, email,
  # url, enum, reference) with no native array/object type. Anything shaped like a list or a
  # nested record (order line items, a shipping address, extra product images) is stored as a
  # JSON string in a `string` field and parsed at the edges - a real, documented constraint of
  # the platform's Collections feature, not a workaround specific to this app. Mirrors
  # `web/src/lib/json-field.ts` in the reference implementation.
  module JsonField
    # @param value [String, nil]
    # @param fallback [Object] returned as-is if `value` is blank or invalid JSON.
    # @return [Object] parsed with symbol keys, matching every other Hash in this app (see
    #   ClientFactory::OBJECT_RESPONSE) - callers read `item[:productId]`, `address[:fullName]`,
    #   never string keys.
    def self.parse(value, fallback)
      return fallback if value.nil? || value.empty?

      JSON.parse(value, symbolize_names: true)
    rescue JSON::ParserError
      fallback
    end

    def self.stringify(value)
      value.to_json
    end
  end
end
