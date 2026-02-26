# frozen_string_literal: true

require "test_helper"

module Messaging
  module Channels
    class WhatsappTest < ActiveSupport::TestCase
      test "raises DeliveryError when recipient has no phone" do
        recipient = OpenStruct.new(email: "customer@example.com")

        error = assert_raises(Messaging::DeliveryError) do
          Whatsapp.new.deliver(to: recipient, body: "Hello!")
        end
        assert_includes error.message, "requires recipient with phone"
      end

      test "raises DeliveryError when phone is blank" do
        recipient = OpenStruct.new(phone: "")

        assert_raises(Messaging::DeliveryError) do
          Whatsapp.new.deliver(to: recipient, body: "Hello!")
        end
      end

      test "raises DeliveryError when Twilio is not configured" do
        recipient = OpenStruct.new(phone: "+5511999999999")
        # Without TWILIO_* env vars or credentials, should raise

        error = assert_raises(Messaging::DeliveryError) do
          Whatsapp.new.deliver(to: recipient, body: "Hello!")
        end
        assert_includes error.message, "not configured"
      end

      test "accepts string as recipient (phone number)" do
        error = assert_raises(Messaging::DeliveryError) do
          Whatsapp.new.deliver(to: "+5511999999999", body: "Hi")
        end
        # Fails on configuration, not on recipient - so we got past recipient validation
        assert_includes error.message, "not configured"
      end
    end
  end
end
