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

    test "raises ArgumentError when channel is unknown" do
      recipient = OpenStruct.new(email: "test@example.com")

      assert_raises(ArgumentError) do
        DeliveryService.call(channel: :sms, to: recipient, body: "Hi")
      end
    end

    test "accepts channel as string" do
      recipient = OpenStruct.new(email: "test@example.com")
      result = DeliveryService.call(channel: "email", to: recipient, body: "Hi", subject: "Test")

      assert result[:success]
    end

    test "returns error hash for whatsapp when not configured" do
      # Uses a real customer (has space + credits); Twilio isn't configured in test env
      # so delivery fails, credits are deducted then refunded atomically.
      customer = customers(:one)

      result = DeliveryService.call(channel: :whatsapp, to: customer, body: "Hi")

      assert_not result[:success]
      assert_includes result[:error], "not configured"
    end

    # ── Credit integration ────────────────────────────────────────────────────

    test "whatsapp send with sufficient credits deducts 1 credit and succeeds" do
      customer = customers(:one)
      credit   = Billing::MessageCredit.find_by!(space: customer.space)
      initial_quota = credit.monthly_quota_remaining

      fake_channel = Object.new
      fake_channel.define_singleton_method(:deliver) { |**| { success: true } }

      Messaging::Channels::Whatsapp.stub(:new, fake_channel) do
        result = DeliveryService.call(channel: :whatsapp, to: customer, body: "Hi")
        assert result[:success]
      end

      credit.reload
      assert_equal initial_quota - 1, credit.monthly_quota_remaining
    end

    test "whatsapp send with zero credits returns insufficient error without delivering" do
      customer = customers(:one)
      credit   = Billing::MessageCredit.find_by!(space: customer.space)
      credit.update!(balance: 0, monthly_quota_remaining: 0)

      delivered = false
      fake_channel = Object.new
      fake_channel.define_singleton_method(:deliver) { |**| delivered = true; { success: true } }

      Messaging::Channels::Whatsapp.stub(:new, fake_channel) do
        result = DeliveryService.call(channel: :whatsapp, to: customer, body: "Hi")
        assert_not result[:success]
        assert_equal "insufficient_whatsapp_credits", result[:error]
      end

      assert_not delivered, "Channel should not be called when credits are insufficient"
    end

    test "whatsapp delivery failure refunds the deducted credit" do
      customer = customers(:one)
      credit   = Billing::MessageCredit.find_by!(space: customer.space)
      credit.update!(monthly_quota_remaining: 10, balance: 0)

      fake_channel = Object.new
      fake_channel.define_singleton_method(:deliver) do |**|
        raise Messaging::DeliveryError, "upstream failure"
      end

      Messaging::Channels::Whatsapp.stub(:new, fake_channel) do
        result = DeliveryService.call(channel: :whatsapp, to: customer, body: "Hi")
        assert_not result[:success]
        assert_equal "upstream failure", result[:error]
      end

      credit.reload
      assert_equal 10, credit.monthly_quota_remaining, "Credit must be refunded after delivery failure"
    end

    test "email send has no credit interaction" do
      customer = customers(:one)
      customer.update!(email: "customer@example.com")
      credit = Billing::MessageCredit.find_by!(space: customer.space)
      initial_balance = credit.balance
      initial_quota   = credit.monthly_quota_remaining

      DeliveryService.call(channel: :email, to: customer, body: "Hi", subject: "Test")

      credit.reload
      assert_equal initial_balance, credit.balance
      assert_equal initial_quota,   credit.monthly_quota_remaining
    end
  end
end
