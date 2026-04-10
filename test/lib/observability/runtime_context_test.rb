# frozen_string_literal: true

require "test_helper"

module Observability
  class RuntimeContextTest < ActiveSupport::TestCase
    FakeContext = Struct.new(:valid, :hex_trace_id, :hex_span_id, keyword_init: true) do
      def valid?
        valid
      end
    end

    FakeSpan = Struct.new(:context, keyword_init: true)

    test "uses default service metadata when env overrides are missing" do
      with_env("APP_VERSION" => nil, "OTEL_SERVICE_NAME" => nil, "OTEL_DEPLOYMENT_ENVIRONMENT" => nil) do
        assert_equal "dev", RuntimeContext.app_version
        assert_equal "appointment-scheduler", RuntimeContext.service_name
        assert_equal Rails.env, RuntimeContext.deployment_environment
        assert_equal({ "deployment.environment" => Rails.env }, RuntimeContext.resource_attributes)
      end
    end

    test "uses explicit env overrides for service metadata" do
      with_env(
        "APP_VERSION" => "2026.04.10+sha.abc123",
        "OTEL_SERVICE_NAME" => "appointment-scheduler-prod",
        "OTEL_DEPLOYMENT_ENVIRONMENT" => "production"
      ) do
        assert_equal "2026.04.10+sha.abc123", RuntimeContext.app_version
        assert_equal "appointment-scheduler-prod", RuntimeContext.service_name
        assert_equal "production", RuntimeContext.deployment_environment
        assert_equal({ "deployment.environment" => "production" }, RuntimeContext.resource_attributes)
      end
    end

    test "adds trace correlation fields when a valid span is active" do
      span = FakeSpan.new(
        context: FakeContext.new(valid: true, hex_trace_id: "a" * 32, hex_span_id: "b" * 16)
      )

      OpenTelemetry::Trace.stub(:current_span, span) do
        payload = RuntimeContext.log_payload

        assert_equal "a" * 32, payload[:trace_id]
        assert_equal "b" * 16, payload[:span_id]
      end
    end

    test "omits trace correlation fields when the span is invalid" do
      payload = RuntimeContext.log_trace_context(
        span: FakeSpan.new(context: FakeContext.new(valid: false, hex_trace_id: "a" * 32, hex_span_id: "b" * 16))
      )

      assert_equal({}, payload)
    end

    private

    def with_env(overrides)
      original_values = overrides.keys.to_h { |key| [ key, ENV[key] ] }

      overrides.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end

      yield
    ensure
      original_values.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
  end
end
