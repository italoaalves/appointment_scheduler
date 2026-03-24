# frozen_string_literal: true

require "test_helper"

module Billing
  class WebhookProcessorTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    # ── Helpers ───────────────────────────────────────────────────────────────

    setup do
      @space = Space.create!(name: "Webhook Test Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update_columns(asaas_subscription_id: "sub_asaas_test")
    end

    def payment_payload(event:, payment_id: "pay_001", status: "CONFIRMED", billing_type: "PIX", value: 99.0, due_date: nil)
      {
        "event" => event,
        "payment" => {
          "id"            => payment_id,
          "subscription"  => @subscription.asaas_subscription_id,
          "value"         => value,
          "billingType"   => billing_type,
          "status"        => status,
          "confirmedDate" => Date.current.to_s,
          "dueDate"       => due_date
        }.compact
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

    test "PAYMENT_CONFIRMED BillingEvent metadata includes plan_slug" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

      event = Billing::BillingEvent.find_by(event_type: "webhook.payment_confirmed")
      assert_equal @subscription.plan.slug, event.metadata["plan_slug"]
    end

    test "PAYMENT_CONFIRMED updates current_period_start to confirmedDate" do
      freeze_time do
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

        @subscription.reload
        assert_equal Date.current.in_time_zone.to_i, @subscription.current_period_start.to_i
      end
    end

    test "PAYMENT_CONFIRMED sets current_period_end to 1 month after the period anchor" do
      freeze_time do
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED"))

        @subscription.reload
        assert_equal (Date.current.in_time_zone + 1.month).to_i, @subscription.current_period_end.to_i
      end
    end

    test "PAYMENT_CONFIRMED prefers dueDate over confirmedDate as period_start" do
      due_date = 2.days.ago.to_date

      freeze_time do
        Billing::WebhookProcessor.call(
          payment_payload(event: "PAYMENT_CONFIRMED", due_date: due_date.to_s)
        )

        @subscription.reload
        assert_equal due_date.in_time_zone.to_i, @subscription.current_period_start.to_i
        assert_equal (due_date.in_time_zone + 1.month).to_i, @subscription.current_period_end.to_i
      end
    end

    test "PAYMENT_CONFIRMED for credit purchase does NOT update billing period" do
      original_start = 5.days.ago
      original_end   = 25.days.from_now
      @subscription.update_columns(
        current_period_start: original_start,
        current_period_end:   original_end
      )

      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_period_check"
      )

      Billing::WebhookProcessor.call(
        credit_purchase_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_cp_period_check", purchase_id: purchase.id)
      )

      @subscription.reload
      assert_in_delta original_start.to_i, @subscription.current_period_start.to_i, 1
      assert_in_delta original_end.to_i,   @subscription.current_period_end.to_i,   1
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

    test "PAYMENT_OVERDUE after PAYMENT_CONFIRMED does NOT transition subscription to past_due" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:active])

      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_ooo_01"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_OVERDUE",   payment_id: "pay_ooo_01"))

      assert @subscription.reload.active?
    end

    test "PAYMENT_OVERDUE after PAYMENT_CONFIRMED does NOT change payment status to overdue" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_ooo_02"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_OVERDUE",   payment_id: "pay_ooo_02"))

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_ooo_02")
      assert payment.confirmed?
    end

    test "PAYMENT_OVERDUE after PAYMENT_CONFIRMED does NOT create a webhook.payment_overdue BillingEvent" do
      # Regression for R-03: return inside transaction caused implicit COMMIT,
      # which could leave orphaned Payment or BillingEvent records.
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_ooo_audit"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_OVERDUE",   payment_id: "pay_ooo_audit"))

      overdue_events = Billing::BillingEvent.where(event_type: "webhook.payment_overdue")
                                            .where("metadata->>'asaas_payment_id' = ?", "pay_ooo_audit")
      assert_equal 0, overdue_events.count,
        "No webhook.payment_overdue BillingEvent should be created for an already-confirmed payment"
    end

    test "PAYMENT_DELETED after PAYMENT_CONFIRMED does NOT mark payment as failed" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_ooo_03"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_DELETED",   payment_id: "pay_ooo_03"))

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_ooo_03")
      assert payment.confirmed?
    end

    test "PAYMENT_DELETED with no prior payment record returns without error" do
      assert_nothing_raised do
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_DELETED", payment_id: "pay_ooo_04"))
      end

      assert_nil Billing::Payment.find_by(asaas_payment_id: "pay_ooo_04")
    end

    test "PAYMENT_DELETED with a pending payment marks it as failed" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_ooo_05"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_DELETED", payment_id: "pay_ooo_05"))

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_ooo_05")
      assert payment.failed?
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

    test "PAYMENT_CREATED stores due_date from webhook payload" do
      target_date = 5.days.from_now.to_date

      Billing::WebhookProcessor.call(
        payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_due_001", due_date: target_date.to_s)
      )

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_due_001")
      assert_equal target_date, payment.due_date
    end

    test "PAYMENT_CREATED for PIX subscription enqueues PaymentReminderJob" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:pix])

      assert_enqueued_with(job: Billing::PaymentReminderJob) do
        Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_pix_001"))
      end
    end

    test "PAYMENT_CREATED for Boleto subscription enqueues PaymentReminderJob" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:boleto])

      assert_enqueued_with(job: Billing::PaymentReminderJob) do
        Billing::WebhookProcessor.call(
          payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_bol_001", billing_type: "BOLETO")
        )
      end
    end

    test "PAYMENT_CREATED for credit_card subscription does not enqueue PaymentReminderJob" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:credit_card])

      assert_no_enqueued_jobs(only: Billing::PaymentReminderJob) do
        Billing::WebhookProcessor.call(
          payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_cc_001", billing_type: "CREDIT_CARD")
        )
      end
    end

    # ── SUBSCRIPTION_DELETED ──────────────────────────────────────────────────

    def subscription_deleted_payload(asaas_subscription_id: "sub_asaas_test")
      { "event" => "SUBSCRIPTION_DELETED", "subscription" => { "id" => asaas_subscription_id } }.to_json
    end

    test "SUBSCRIPTION_DELETED transitions subscription to expired" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:canceled])

      Billing::WebhookProcessor.call(subscription_deleted_payload)

      assert @subscription.reload.expired?
    end

    test "SUBSCRIPTION_DELETED sets canceled_at if not already set" do
      @subscription.update_columns(status: Billing::Subscription.statuses[:canceled], canceled_at: nil)

      freeze_time do
        Billing::WebhookProcessor.call(subscription_deleted_payload)

        assert_in_delta Time.current.to_i, @subscription.reload.canceled_at.to_i, 2
      end
    end

    test "SUBSCRIPTION_DELETED on already-expired subscription does not change state" do
      @subscription.update_columns(
        status:      Billing::Subscription.statuses[:expired],
        canceled_at: 5.days.ago
      )
      original_canceled_at = @subscription.canceled_at

      Billing::WebhookProcessor.call(subscription_deleted_payload)

      @subscription.reload
      assert @subscription.expired?
      assert_in_delta original_canceled_at.to_i, @subscription.canceled_at.to_i, 2
    end

    test "SUBSCRIPTION_DELETED is idempotent — does not create duplicate BillingEvents" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:canceled])

      Billing::WebhookProcessor.call(subscription_deleted_payload)
      Billing::WebhookProcessor.call(subscription_deleted_payload)

      count = Billing::BillingEvent.where(event_type: "webhook.subscription_deleted")
                                   .where("metadata->>'asaas_subscription_id' = ?", "sub_asaas_test")
                                   .count
      assert_equal 1, count
    end

    test "SUBSCRIPTION_DELETED for unknown asaas_subscription_id logs warning and returns gracefully" do
      assert_nothing_raised do
        Billing::WebhookProcessor.call(subscription_deleted_payload(asaas_subscription_id: "sub_unknown"))
      end
    end

    # ── PAYMENT_REPROVED_BY_RISK_ANALYSIS / PAYMENT_CREDIT_CARD_CAPTURE_REFUSED / PAYMENT_BANK_SLIP_CANCELLED ──

    test "PAYMENT_REPROVED_BY_RISK_ANALYSIS marks pending payment as failed" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_risk_001"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_REPROVED_BY_RISK_ANALYSIS", payment_id: "pay_risk_001"))

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_risk_001")
      assert payment.failed?
    end

    test "PAYMENT_CREDIT_CARD_CAPTURE_REFUSED marks pending payment as failed" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_cc_001"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREDIT_CARD_CAPTURE_REFUSED", payment_id: "pay_cc_001"))

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_cc_001")
      assert payment.failed?
    end

    test "PAYMENT_BANK_SLIP_CANCELLED marks pending payment as failed" do
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_CREATED", payment_id: "pay_boleto_001"))
      Billing::WebhookProcessor.call(payment_payload(event: "PAYMENT_BANK_SLIP_CANCELLED", payment_id: "pay_boleto_001"))

      payment = Billing::Payment.find_by(asaas_payment_id: "pay_boleto_001")
      assert payment.failed?
    end

    # ── SUBSCRIPTION_INACTIVATED ──────────────────────────────────────────────

    def subscription_inactivated_payload(asaas_subscription_id: "sub_asaas_test")
      { "event" => "SUBSCRIPTION_INACTIVATED", "subscription" => { "id" => asaas_subscription_id } }.to_json
    end

    test "SUBSCRIPTION_INACTIVATED logs a BillingEvent" do
      assert_difference -> { Billing::BillingEvent.where(event_type: "webhook.subscription_inactivated").count } do
        Billing::WebhookProcessor.call(subscription_inactivated_payload)
      end

      event = Billing::BillingEvent.find_by(event_type: "webhook.subscription_inactivated")
      assert_equal "sub_asaas_test", event.metadata["asaas_subscription_id"]
    end

    test "SUBSCRIPTION_INACTIVATED does NOT change subscription status" do
      original_status = @subscription.status

      Billing::WebhookProcessor.call(subscription_inactivated_payload)

      assert_equal original_status, @subscription.reload.status
    end

    test "SUBSCRIPTION_INACTIVATED is idempotent — duplicate webhook creates only one BillingEvent" do
      Billing::WebhookProcessor.call(subscription_inactivated_payload)
      Billing::WebhookProcessor.call(subscription_inactivated_payload)

      count = Billing::BillingEvent.where(event_type: "webhook.subscription_inactivated")
                                   .where("metadata->>'asaas_subscription_id' = ?", "sub_asaas_test")
                                   .count
      assert_equal 1, count
    end

    test "SUBSCRIPTION_INACTIVATED for unknown subscription logs warning and returns gracefully" do
      assert_nothing_raised do
        Billing::WebhookProcessor.call(subscription_inactivated_payload(asaas_subscription_id: "sub_unknown_inactivated"))
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

    # ── externalReference prefix guard (C-06) ────────────────────────────────

    test "PAYMENT_CONFIRMED with non-space externalReference does not match a subscription" do
      payload = {
        "event" => "PAYMENT_CONFIRMED",
        "payment" => {
          "id"                => "pay_guard_001",
          "value"             => 99.0,
          "billingType"       => "PIX",
          "confirmedDate"     => Date.current.to_s,
          "externalReference" => "workspace_#{@subscription.space_id}"
        }
      }.to_json

      assert_nothing_raised { Billing::WebhookProcessor.call(payload) }
      assert_nil Billing::Payment.find_by(asaas_payment_id: "pay_guard_001")
    end

    test "PAYMENT_CONFIRMED with credit_purchase externalReference does not match subscription" do
      payload = {
        "event" => "PAYMENT_CONFIRMED",
        "payment" => {
          "id"                => "pay_guard_002",
          "value"             => 25.0,
          "billingType"       => "PIX",
          "confirmedDate"     => Date.current.to_s,
          "externalReference" => "credit_purchase_9999"
        }
      }.to_json

      assert_nothing_raised { Billing::WebhookProcessor.call(payload) }
      assert_nil Billing::Payment.find_by(asaas_payment_id: "pay_guard_002")
    end

    # ── Credit purchase webhook handling ─────────────────────────────────────

    def credit_purchase_payload(event:, payment_id: "pay_cp_001", purchase_id:)
      {
        "event"   => event,
        "payment" => {
          "id"                => payment_id,
          "value"             => 25.0,
          "billingType"       => "PIX",
          "status"            => "CONFIRMED",
          "confirmedDate"     => Date.current.to_s,
          "externalReference" => "credit_purchase_#{purchase_id}"
        }
      }.to_json
    end

    test "PAYMENT_CONFIRMED for credit purchase fulfills it and adds balance" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_001"
      )

      Billing::WebhookProcessor.call(credit_purchase_payload(event: "PAYMENT_CONFIRMED", purchase_id: purchase.id))

      assert purchase.reload.completed?
      credit = Billing::MessageCredit.find_by(space_id: @space.id)
      assert_not_nil credit
      assert_equal 50, credit.balance
    end

    test "PAYMENT_CONFIRMED for credit purchase is idempotent" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_002"
      )

      Billing::WebhookProcessor.call(credit_purchase_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_cp_002", purchase_id: purchase.id))
      Billing::WebhookProcessor.call(credit_purchase_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_cp_002", purchase_id: purchase.id))

      credit = Billing::MessageCredit.find_by(space_id: @space.id)
      assert_equal 50, credit.balance  # granted exactly once
    end

    test "PAYMENT_CONFIRMED for credit purchase does NOT affect subscription status" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:trialing])

      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_003"
      )

      Billing::WebhookProcessor.call(credit_purchase_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_cp_003", purchase_id: purchase.id))

      assert @subscription.reload.trialing?  # subscription status unchanged
    end

    test "PAYMENT_OVERDUE for credit purchase marks it as failed" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_004"
      )

      Billing::WebhookProcessor.call(
        { "event" => "PAYMENT_OVERDUE",
          "payment" => { "id" => "pay_cp_004", "externalReference" => "credit_purchase_#{purchase.id}" } }.to_json
      )

      assert purchase.reload.failed?
    end

    test "PAYMENT_DELETED for credit purchase marks it as failed" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_005"
      )

      Billing::WebhookProcessor.call(
        { "event" => "PAYMENT_DELETED",
          "payment" => { "id" => "pay_cp_005", "externalReference" => "credit_purchase_#{purchase.id}" } }.to_json
      )

      assert purchase.reload.failed?
    end

    test "PAYMENT_OVERDUE for credit purchase enqueues CreditPurchaseFailedNotificationJob" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_notif_001"
      )

      assert_enqueued_with(job: Billing::CreditPurchaseFailedNotificationJob, args: [ purchase.id ]) do
        Billing::WebhookProcessor.call(
          { "event" => "PAYMENT_OVERDUE",
            "payment" => { "id" => "pay_cp_notif_001", "externalReference" => "credit_purchase_#{purchase.id}" } }.to_json
        )
      end
    end

    test "PAYMENT_DELETED for credit purchase enqueues CreditPurchaseFailedNotificationJob" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_notif_002"
      )

      assert_enqueued_with(job: Billing::CreditPurchaseFailedNotificationJob, args: [ purchase.id ]) do
        Billing::WebhookProcessor.call(
          { "event" => "PAYMENT_DELETED",
            "payment" => { "id" => "pay_cp_notif_002", "externalReference" => "credit_purchase_#{purchase.id}" } }.to_json
        )
      end
    end

    test "PAYMENT_OVERDUE for credit purchase does not affect subscription" do
      @subscription.update_column(:status, Billing::Subscription.statuses[:active])

      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_006"
      )

      Billing::WebhookProcessor.call(
        { "event" => "PAYMENT_OVERDUE",
          "payment" => { "id" => "pay_cp_006", "externalReference" => "credit_purchase_#{purchase.id}" } }.to_json
      )

      assert @subscription.reload.active?  # subscription status unchanged
    end

    test "PAYMENT_CONFIRMED for credit purchase using externalReference fallback when asaas_payment_id not stored" do
      purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: Billing::CreditBundle.available.find_by!(amount: 50),
        amount:        50,
        price_cents:   2500,
        status:        :pending
        # no asaas_payment_id set — simulates race condition
      )

      Billing::WebhookProcessor.call(
        { "event" => "PAYMENT_CONFIRMED",
          "payment" => {
            "id"                => "pay_cp_007",
            "value"             => 25.0,
            "billingType"       => "PIX",
            "confirmedDate"     => Date.current.to_s,
            "externalReference" => "credit_purchase_#{purchase.id}"
          } }.to_json
      )

      assert purchase.reload.completed?
    end

    test "PAYMENT_RECEIVED for credit purchase fulfills it and adds balance" do
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    Billing::CreditBundle.available.find_by!(amount: 50),
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_recv_001"
      )

      Billing::WebhookProcessor.call(
        credit_purchase_payload(event: "PAYMENT_RECEIVED", payment_id: "pay_cp_recv_001", purchase_id: purchase.id)
      )

      assert purchase.reload.completed?
      assert_equal 50, Billing::MessageCredit.find_by!(space_id: @space.id).balance
    end

    test "fulfillment error propagates from WebhookProcessor when credit bundle is deactivated" do
      bundle = Billing::CreditBundle.available.find_by!(amount: 50)
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    bundle,
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_err_001"
      )

      bundle.update!(active: false)

      assert_raises(ActiveRecord::RecordNotFound) do
        Billing::WebhookProcessor.call(
          credit_purchase_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_cp_err_001", purchase_id: purchase.id)
        )
      end

      assert purchase.reload.pending?  # credits NOT granted, status unchanged
    end

    test "fulfillment error leaves CreditPurchase pending — no partial grant" do
      bundle = Billing::CreditBundle.available.find_by!(amount: 50)
      purchase = Billing::CreditPurchase.create!(
        space:            @space,
        credit_bundle:    bundle,
        amount:           50,
        price_cents:      2500,
        status:           :pending,
        asaas_payment_id: "pay_cp_atomic_001"
      )

      bundle.update!(active: false)

      assert_raises(ActiveRecord::RecordNotFound) do
        Billing::WebhookProcessor.call(
          credit_purchase_payload(event: "PAYMENT_CONFIRMED", payment_id: "pay_cp_atomic_001", purchase_id: purchase.id)
        )
      end

      credit = Billing::MessageCredit.find_by(space_id: @space.id)
      assert_equal 0, credit&.balance.to_i  # balance not incremented
      assert purchase.reload.pending?        # status unchanged
    end
  end
end
