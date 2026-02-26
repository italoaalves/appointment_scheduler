# frozen_string_literal: true

require "test_helper"

module Messaging
  module Channels
    class EmailTest < ActiveSupport::TestCase
      setup do
        ActionMailer::Base.deliveries.clear
      end

      test "delivers email to recipient with email" do
        recipient = OpenStruct.new(email: "customer@example.com")
        result = Email.new.deliver(to: recipient, body: "Hello!", subject: "Test")

        assert result[:success]
        assert_equal 1, ActionMailer::Base.deliveries.size
        mail = ActionMailer::Base.deliveries.first
        assert_equal ["customer@example.com"], mail.to
        assert_equal "Test", mail.subject
        assert_includes mail.body.encoded, "Hello!"
      end

      test "accepts string as recipient (email address)" do
        result = Email.new.deliver(to: "direct@example.com", body: "Hi", subject: "Direct")

        assert result[:success]
        assert_equal ["direct@example.com"], ActionMailer::Base.deliveries.first.to
      end

      test "uses default subject when subject is blank" do
        recipient = OpenStruct.new(email: "customer@example.com")
        Email.new.deliver(to: recipient, body: "Hello!", subject: nil)
        assert_equal "Message", ActionMailer::Base.deliveries.first.subject
      end

      test "raises DeliveryError when recipient has no email" do
        recipient = OpenStruct.new(phone: "+5511999999999")

        error = assert_raises(Messaging::DeliveryError) do
          Email.new.deliver(to: recipient, body: "Hello!")
        end
        assert_includes error.message, "requires recipient with email"
      end

      test "raises DeliveryError when email is blank" do
        recipient = OpenStruct.new(email: "")

        assert_raises(Messaging::DeliveryError) do
          Email.new.deliver(to: recipient, body: "Hello!")
        end
      end
    end
  end
end
