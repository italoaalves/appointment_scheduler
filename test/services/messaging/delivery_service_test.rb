# frozen_string_literal: true

require "test_helper"

module Messaging
  class DeliveryServiceTest < ActiveSupport::TestCase
    setup do
      ActionMailer::Base.deliveries.clear
    end

    test "delivers via email channel" do
      customer = customers(:one)
      customer.update!(email: "customer@example.com")

      result = DeliveryService.call(
        channel: :email,
        to: customer,
        body: "Your appointment is confirmed.",
        subject: "Appointment Confirmation"
      )

      assert result[:success]
      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.first
      assert_equal [ "customer@example.com" ], mail.to
      assert_equal "Appointment Confirmation", mail.subject
      assert_includes mail.body.encoded, "Your appointment is confirmed"
    end

    test "returns success hash from channel" do
      recipient = OpenStruct.new(email: "test@example.com")
      result = DeliveryService.call(channel: :email, to: recipient, body: "Hi", subject: "Test")

      assert_equal({ success: true }, result)
    end

    test "returns error hash when email recipient has no email" do
      recipient = OpenStruct.new(phone: "+5511999999999")

      result = DeliveryService.call(channel: :email, to: recipient, body: "Hi")

      assert_not result[:success]
      assert result[:error].present?
      assert_includes result[:error], "requires recipient with email"
    end

    test "returns error hash when channel is unknown" do
      recipient = OpenStruct.new(email: "test@example.com")

      result = DeliveryService.call(channel: :sms, to: recipient, body: "Hi")

      assert_not result[:success]
      assert_includes result[:error], "Unknown channel"
    end

    test "accepts channel as string" do
      recipient = OpenStruct.new(email: "test@example.com")
      result = DeliveryService.call(channel: "email", to: recipient, body: "Hi", subject: "Test")

      assert result[:success]
    end

    test "returns error hash for whatsapp when not configured" do
      recipient = OpenStruct.new(phone: "+5511999999999")

      result = DeliveryService.call(channel: :whatsapp, to: recipient, body: "Hi")

      assert_not result[:success]
      assert_includes result[:error], "not configured"
    end
  end
end
