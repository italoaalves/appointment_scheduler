# frozen_string_literal: true

module Observability
  module RuntimeContext
    DEFAULT_APP_VERSION = "dev"
    DEFAULT_SERVICE_NAME = "appointment-scheduler"
    DEPLOYMENT_ENVIRONMENT_ATTRIBUTE = "deployment.environment"

    module_function

    def app_version
      ENV["APP_VERSION"].presence || DEFAULT_APP_VERSION
    end

    def service_name
      ENV["OTEL_SERVICE_NAME"].presence || DEFAULT_SERVICE_NAME
    end

    def deployment_environment
      ENV["OTEL_DEPLOYMENT_ENVIRONMENT"].presence || Rails.env.to_s
    end

    def resource_attributes
      {
        DEPLOYMENT_ENVIRONMENT_ATTRIBUTE => deployment_environment
      }
    end

    def log_payload
      {
        deployment_environment: deployment_environment,
        service_name: service_name,
        service_version: app_version
      }.merge(log_trace_context)
    end

    def log_trace_context(span: current_span)
      context = span&.context
      return {} unless context&.valid?

      {
        trace_id: context.hex_trace_id,
        span_id: context.hex_span_id
      }
    rescue StandardError
      {}
    end

    def current_span
      return unless defined?(OpenTelemetry::Trace)

      OpenTelemetry::Trace.current_span
    end
  end
end
