# frozen_string_literal: true

require "test_helper"

class LogrageTest < ActiveSupport::TestCase
  FakeContext = Struct.new(:valid, :hex_trace_id, :hex_span_id, keyword_init: true) do
    def valid?
      valid
    end
  end

  FakeSpan = Struct.new(:context, keyword_init: true)

  test "custom options filter LGPD-sensitive params without logging raw exception messages" do
    event = OpenStruct.new(
      payload: {
        params: {
          controller: "booking",
          action: "create",
          customer_name: "Maria Silva",
          customer_phone: "+5511999990199",
          customer_address: "Rua Segura, 99",
          scheduled_at: "2026-04-08 10:00",
          body: "Prefers afternoon reminders"
        },
        exception: [ "RuntimeError", "boom" ],
        exception_object: RuntimeError.new("Customer Maria Silva failed validation")
      }
    )

    span = FakeSpan.new(
      context: FakeContext.new(valid: true, hex_trace_id: "a" * 32, hex_span_id: "b" * 16)
    )

    options = OpenTelemetry::Trace.stub(:current_span, span) do
      Rails.application.config.lograge.custom_options.call(event)
    end

    assert_equal "[FILTERED]", options[:params]["customer_name"]
    assert_equal "[FILTERED]", options[:params]["customer_phone"]
    assert_equal "[FILTERED]", options[:params]["customer_address"]
    assert_equal "[FILTERED]", options[:params]["scheduled_at"]
    assert_equal "[FILTERED]", options[:params]["body"]
    assert_equal "RuntimeError", options[:exception]
    assert_equal "a" * 32, options[:trace_id]
    assert_equal "b" * 16, options[:span_id]
    assert_equal Rails.env, options[:deployment_environment]
    assert_equal "appointment-scheduler", options[:service_name]
    assert_equal "dev", options[:service_version]
    refute_includes options[:params].keys, "controller"
    refute_includes options[:params].keys, "action"
    assert_not options.key?(:exception_message)
  end
end
