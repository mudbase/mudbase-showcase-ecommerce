# frozen_string_literal: true

require "time"

# ERB helpers shared by every view. Mirrors `web/src/lib/utils.ts` in the reference app so the
# two implementations produce the same formatted output for the same data.
module ViewHelpers
  CURRENCY_SYMBOLS = { "USD" => "$", "USDC" => "$" }.freeze

  def format_money(cents, currency = "USD")
    return "" if cents.nil?

    symbol = CURRENCY_SYMBOLS[currency] || "#{currency} "
    format("%s%.2f", symbol, cents / 100.0)
  end

  def format_date(iso_string)
    return "" if iso_string.nil? || iso_string.empty?

    Time.parse(iso_string).strftime("%b %-d, %Y %-I:%M %p")
  rescue ArgumentError
    iso_string
  end

  def slugify(value)
    value.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
  end

  def discount_percent(price_cents, compare_at_price_cents)
    return nil if compare_at_price_cents.nil? || compare_at_price_cents <= price_cents

    ((1 - price_cents.to_f / compare_at_price_cents) * 100).round
  end

  def short_order_id(order_id)
    order_id.to_s[-6..].to_s.upcase
  end

  def order_status_label(status)
    {
      "pending" => "Pending",
      "awaiting_payment" => "Awaiting payment",
      "paid" => "Paid",
      "shipped" => "Shipped",
      "delivered" => "Delivered",
      "cancelled" => "Cancelled",
    }.fetch(status, status)
  end

  def order_status_variant(status)
    case status
    when "delivered", "paid" then "success"
    when "cancelled" then "danger"
    when "awaiting_payment", "pending" then "warning"
    else "secondary"
    end
  end

  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end
end
