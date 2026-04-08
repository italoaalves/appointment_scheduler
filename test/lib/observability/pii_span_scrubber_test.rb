# frozen_string_literal: true

require "test_helper"

module Observability
  class PiiSpanScrubberTest < ActiveSupport::TestCase
    FakeSpan = Struct.new(:attributes, keyword_init: true) do
      def set_attribute(key, value)
        attributes[key] = value
      end
    end

    test "scrubs query-bearing span attributes before export" do
      span = FakeSpan.new(attributes: {
        "url.query" => "customer_phone=%2B5511999990111&customer_name=Maria",
        "http.target" => "/booking?customer_phone=%2B5511999990111",
        "url.full" => "https://example.com/booking?customer_phone=%2B5511999990111",
        "http.url" => "https://api.example.com/messages?to=%2B5511999990111"
      })

      PiiSpanScrubber.new.on_finishing(span)

      assert_equal "[FILTERED]", span.attributes["url.query"]
      assert_equal "/booking?[FILTERED]", span.attributes["http.target"]
      assert_equal "https://example.com/booking?[FILTERED]", span.attributes["url.full"]
      assert_equal "https://api.example.com/messages?[FILTERED]", span.attributes["http.url"]
    end

    test "leaves non-query attributes unchanged" do
      span = FakeSpan.new(attributes: {
        "http.target" => "/health",
        "url.full" => "https://example.com/health"
      })

      PiiSpanScrubber.new.on_finishing(span)

      assert_equal "/health", span.attributes["http.target"]
      assert_equal "https://example.com/health", span.attributes["url.full"]
    end
  end
end
