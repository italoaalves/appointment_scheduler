# frozen_string_literal: true

module Observability
  class FilteredParams
    DEFAULT_EXCLUDED_KEYS = %w[controller action format].freeze

    class << self
      def call(params, except: DEFAULT_EXCLUDED_KEYS)
        return if params.blank?

        filtered = parameter_filter.filter(normalize(params))
        filtered.except(*Array(except).map(&:to_s))
      end

      private

      def parameter_filter
        @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      end

      def normalize(params)
        raw =
          if params.respond_to?(:to_unsafe_h)
            params.to_unsafe_h
          elsif params.respond_to?(:to_h)
            params.to_h
          else
            params
          end

        raw.deep_stringify_keys
      end
    end
  end
end
