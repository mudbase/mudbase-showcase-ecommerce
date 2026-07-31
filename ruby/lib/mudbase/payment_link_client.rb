# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require_relative "config"

module Mudbase
  # Creating a Payment Link (`POST /api/orgs/:orgId/payment-links`) requires a live org
  # owner/admin bearer session - there is no API-key path for it, and the generated Ruby SDK
  # has no dedicated Payment Links API class at all (it isn't part of the OpenAPI surface this
  # client was generated from; confirmed by grepping every `lib/mudbase_sdk/api/*.rb` file).
  # Every per-language reimplementation of this storefront shares one Mudbase project, so this
  # app deliberately does NOT hold that merchant credential itself - creating one would mean
  # every reimplementation independently rotates the same single-use merchant refresh token, a
  # real race condition the moment two of them run checkout concurrently. Instead this proxies
  # to the already-deployed reference Next.js app's Route Handler, which holds that credential
  # once, server-side (see its `src/lib/mudbase-server.ts`). Both calls here are plain REST -
  # the public payment-link status read is unauthenticated by design, same as the proxy target.
  class PaymentLinkResult
    attr_reader :ok, :link, :error_message, :error_reason, :http_status

    def initialize(ok:, link: nil, error_message: nil, error_reason: nil, http_status: nil)
      @ok = ok
      @link = link
      @error_message = error_message
      @error_reason = error_reason
      @http_status = http_status
    end

    def ok?
      @ok
    end

    def kyc_required?
      @error_reason == "kyc_required"
    end
  end

  module PaymentLinkClient
    OPEN_TIMEOUT_SECONDS = 8
    READ_TIMEOUT_SECONDS = 15

    # @param order_id [String]
    # @param amount [String] decimal string, e.g. "42.50" - matches the reference app's
    #   `(subtotalCents / 100).toFixed(2)`.
    # @param currency [String] e.g. "USDC"
    # @param network [String] e.g. "POLYGON"
    def self.create_for_order(order_id:, amount:, currency: "USDC", network: "POLYGON")
      uri = URI.parse(Mudbase::Config.pay_link_proxy_url)
      redirect_url = "#{Mudbase::Config.app_base_url}/orders/#{order_id}"

      body = {
        orderId: order_id,
        amount: amount,
        currency: currency,
        network: network,
        redirectUrl: redirect_url,
      }

      response = post_json(uri, body)
      parsed = safe_parse(response.body)

      if response.is_a?(Net::HTTPSuccess)
        PaymentLinkResult.new(ok: true, link: parsed[:link], http_status: response.code.to_i)
      else
        PaymentLinkResult.new(
          ok: false,
          error_message: parsed[:error] || "Couldn't start payment. Please try again.",
          error_reason: parsed[:reason],
          http_status: response.code.to_i,
        )
      end
    rescue StandardError => e
      PaymentLinkResult.new(
        ok: false,
        error_message: "Payments are temporarily unavailable (#{e.class}: #{e.message}).",
        error_reason: "network_error",
      )
    end

    # Public, unauthenticated read - matches the reference app's `usePaymentLinkStatus` poll.
    # @return [Hash, nil] symbol-keyed link hash, or nil if the token isn't found/available.
    def self.public_status(token)
      uri = URI.parse("#{Mudbase::Config.base_url}/api/payment-links/#{token}")
      response = get_json(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body, symbolize_names: true)
      parsed[:link]
    rescue StandardError
      nil
    end

    def self.post_json(uri, body)
      http = build_http(uri)
      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body = body.to_json
      http.request(request)
    end
    private_class_method :post_json

    def self.get_json(uri)
      http = build_http(uri)
      request = Net::HTTP::Get.new(uri.request_uri, "Accept" => "application/json")
      http.request(request)
    end
    private_class_method :get_json

    def self.build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT_SECONDS
      http.read_timeout = READ_TIMEOUT_SECONDS
      http
    end
    private_class_method :build_http

    def self.safe_parse(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
    private_class_method :safe_parse
  end
end
