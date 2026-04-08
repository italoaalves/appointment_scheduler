# frozen_string_literal: true

require "uri"

module Observability
  class PiiSpanScrubber < OpenTelemetry::SDK::Trace::SpanProcessor
    FILTERED = "[FILTERED]"
    QUERY_ATTRIBUTES = %w[url.query].freeze
    TARGET_ATTRIBUTES = %w[http.target].freeze
    FULL_URL_ATTRIBUTES = %w[url.full http.url].freeze

    def on_finishing(span)
      attributes = mutable_attributes(span)
      return if attributes.blank?

      scrub_query_attributes(attributes)
      scrub_target_attributes(attributes)
      scrub_full_url_attributes(attributes)
    end

    private

    def scrub_query_attributes(attributes)
      QUERY_ATTRIBUTES.each do |key|
        next if attributes[key].blank?

        attributes[key] = FILTERED
      end
    end

    def scrub_target_attributes(attributes)
      TARGET_ATTRIBUTES.each do |key|
        value = attributes[key]
        next if value.blank? || !value.include?("?")

        attributes[key] = replace_query(value)
      end
    end

    def scrub_full_url_attributes(attributes)
      FULL_URL_ATTRIBUTES.each do |key|
        value = attributes[key]
        next if value.blank?

        scrubbed = scrub_url(value)
        next if scrubbed == value

        attributes[key] = scrubbed
      end
    end

    def mutable_attributes(span)
      if span.instance_variable_defined?(:@attributes)
        span.instance_variable_get(:@attributes) || span.instance_variable_set(:@attributes, {})
      elsif span.respond_to?(:attributes)
        span.attributes
      end
    end

    def scrub_url(url)
      uri = URI.parse(url)
      return url if uri.query.blank?

      uri.query = FILTERED
      uri.to_s
    rescue URI::InvalidURIError
      replace_query(url)
    end

    def replace_query(value)
      value.sub(/\?.*\z/, "?#{FILTERED}")
    end
  end
end
