# frozen_string_literal: true

require "test_helper"

module Billing
  class ProcessWebhookJobTest < ActiveSupport::TestCase
    test "delegates to WebhookProcessor.call with the payload" do
      payload    = '{"event":"PAYMENT_CONFIRMED","payment":{"id":"pay_123"}}'
      received   = nil

      Billing::WebhookProcessor.stub(:call, ->(p) { received = p }) do
        Billing::ProcessWebhookJob.new.perform(payload: payload)
      end

      assert_equal payload, received
    end

    test "is queued on the default queue" do
      assert_equal "default", Billing::ProcessWebhookJob.new.queue_name
    end
  end
end
