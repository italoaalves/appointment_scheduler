# frozen_string_literal: true

require "test_helper"

class LogrageTest < ActiveSupport::TestCase
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

    options = Rails.application.config.lograge.custom_options.call(event)

    assert_equal "[FILTERED]", options[:params]["customer_name"]
    assert_equal "[FILTERED]", options[:params]["customer_phone"]
    assert_equal "[FILTERED]", options[:params]["customer_address"]
    assert_equal "[FILTERED]", options[:params]["scheduled_at"]
    assert_equal "[FILTERED]", options[:params]["body"]
    assert_equal "RuntimeError", options[:exception]
    refute_includes options[:params].keys, "controller"
    refute_includes options[:params].keys, "action"
    assert_not options.key?(:exception_message)
  end
end
