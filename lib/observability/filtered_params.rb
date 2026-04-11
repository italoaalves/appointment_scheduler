# frozen_string_literal: true

module Observability
  class FilteredParams
    DEFAULT_EXCLUDED_KEYS = %w[controller action format].freeze

    class << self
      def call(params, except: DEFAULT_EXCLUDED_KEYS)
        return if params.blank?

        filtered = filter(params)
        return filtered unless filtered.is_a?(Hash)

        filtered.except(*Array(except).map(&:to_s))
      end

      def filter(value)
        return if value.blank?

        apply_parameter_filter(normalize(value))
      end

      private

      def parameter_filter
        @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      end

      def normalize(value)
        case value
        when ActionController::Parameters
          normalize(value.to_unsafe_h)
        when Hash
          value.each_with_object({}) do |(key, nested_value), normalized|
            normalized[key.to_s] = normalize(nested_value)
          end
        when Array
          value.map { |item| normalize(item) }
        when NilClass, Numeric, String, TrueClass, FalseClass
          value
        when Symbol
          value.to_s
        when Time, Date, DateTime, ActiveSupport::TimeWithZone
          value.iso8601
        else
          value.respond_to?(:to_global_id) ? value.to_global_id.to_s : value.to_s
        end
      end

      def apply_parameter_filter(value)
        case value
        when Hash
          parameter_filter.filter(value)
        when Array
          value.map { |item| apply_parameter_filter(item) }
        else
          value
        end
      end
    end
  end
end
