# frozen_string_literal: true

require "test_helper"

module Billing
  class WebhookProcessorTest < ActiveSupport::TestCase
    # ── Helpers ───────────────────────────────────────────────────────────────

    setup do
      @space = Space.create!(name: "Webhook Test Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update_columns(asaas_subscription_id: "sub_asaas_test")
    end

    def payment_payload(event:, payment_id: "pay_001", status: "CONFIRMED", billing_type: "PIX", value: 99.0)
      {
        "event" => event,
        "payment" => {
          "id"           => payment_id,
          "subscription" => @subscription.asaas_subscription_id,
          "value"        => value,
          "billingType"  => billing_type,
          "status"       => status,
          "confirmedDate" => Date.current.to_s
        }
      }.to_json
    end

    # ── PAYMENT_CONFIRMED ─────────────────────────────────────────────────────

    test "PAYMENT_CONFIRMED marks payment as confirmed and transitions past_due to active" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:past_due])

      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

      @subscription.reload
      assert @subscription.active?

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_001")
      assert_not_nil payment
      assert payment.confirmed?
    end

    test "PAYMENT_CONFIRMED transitions trialing to active on first payment" do
      assert @subscription.trialing?

      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

      assert @subscription.reload.active?
    end

    test "PAYMENT_CONFIRMED does not change active subscription status" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:active])

      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

      assert @subscription.reload.active?
    end

    test "PAYMENT_CONFIRMED is idempotent — processing twice does not create duplicate BillingEvents" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

      count = Billing::BillingEvent.where(event_type: "webhook.payment_confirmed")
                                   .where("metadata->>'asaas_payment_id' = ?", "pay_001")
                                   .count
      assert_equal 1, count
    end

    # ── PAYMENT_RECEIVED ──────────────────────────────────────────────────────

    test "PAYMENT_RECEIVED is treated same as PAYMENT_CONFIRMED" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:past_due])

      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_RECEIVED", payment_id: "pay_002"))

      assert @subscription.reload.active?
    end

    # ── PAYMENT_OVERDUE ───────────────────────────────────────────────────────

    test "PAYMENT_OVERDUE marks payment as overdue and transitions subscription to past_due" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:active])

      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_OVERDUE", payment_id: "pay_003"))

      assert @subscription.reload.past_due?

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_003")
      assert payment.overdue?
    end

    test "PAYMENT_OVERDUE is idempotent" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_OVERDUE", payment_id: "pay_004"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_OVERDUE", payment_id: "pay_004"))

      count = Billing::BillingEvent.where(event_type: "webhook.payment_overdue")
                                   .where("metadata->>'asaas_payment_id' = ?", "pay_004")
                                   .count
      assert_equal 1, count
    end

    # ── PAYMENT_CREATED ───────────────────────────────────────────────────────

    test "PAYMENT_CREATED creates a local Payment record with pending status" do
      assert_difference -> { Billing::Payment.count } do
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_005"))
      end

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_005")
      assert payment.pending?
    end

    test "PAYMENT_CREATED is idempotent — does not duplicate the Payment record" do
      assert_difference -> { Billing::Payment.count }, 1 do
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_006"))
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_006"))
      end
    end

    # ── Unknown / missing subscription ────────────────────────────────────────

    test "unknown event type is logged and does not raise" do
      payload = { "event" => "SOME_NEW_ASAAS_EVENT", "payment" => {} }.to_json
      assert_nothing_raised { Billing::WebhookProcessor.call(payload) }
    end

    test "missing subscription for a webhook logs warning and returns gracefully" do
      payload = {
        "event" => "PAYMENT_CONFIRMED",
        "payment" => { "id" => "pay_orphan", "subscription" => "sub_does_not_exist", "value" => 99.0, "billingType" => "PIX" }
      }.to_json

      assert_nothing_raised { Billing::WebhookProcessor.call(payload) }
    end

    test "invalid JSON payload does not raise" do
      assert_nothing_raised { Billing::WebhookProcessor.call("not json {{") }
    end
  end
end
