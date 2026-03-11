# frozen_string_literal: true

require "test_helper"

module Billing
  class PaymentReminderJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    setup do
      @space        = Space.create!(name: "PaymentReminder Space #{SecureRandom.hex(4)}", timezone: "UTC")
      @space.update!(owner_id: users(:manager).id)
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update_columns(
        payment_method:        Billing::Subscription.payment_methods[:pix],
        asaas_subscription_id: "sub_pr_#{SecureRandom.hex(4)}"
      )
      @payment = Billing::Payment.create!(
        space:            @space,
        subscription:     @subscription,
        asaas_payment_id: "pay_pr_#{SecureRandom.hex(6)}",
        amount_cents:     9900,
        payment_method:   :pix,
        status:           :pending,
        due_date:         3.days.from_now.to_date,
        invoice_url:      "https://asaas.com/pay/abc123"
      )
    end

    # ── Happy path ────────────────────────────────────────────────────────────

    test "creates in-app notification for the space owner" do
      assert_difference "Notification.count", 1 do
        Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
      end

      notif = Notification.last
      assert_equal @space.owner,               notif.user
      assert_equal @payment,                   notif.notifiable
      assert_equal "payment_reminder_created", notif.event_type
    end

    test "sends email to the space owner" do
      assert_emails 1 do
        Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
      end

      assert_equal [ @space.owner.email ], ActionMailer::Base.deliveries.last.to
    end

    test "creates correct notification for approaching reminder_type" do
      Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "approaching")

      assert_equal "payment_reminder_approaching", Notification.last.event_type
    end

    test "creates correct notification for due_today reminder_type" do
      Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "due_today")

      assert_equal "payment_reminder_due_today", Notification.last.event_type
    end

    test "creates correct notification for overdue reminder_type" do
      Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "overdue")

      assert_equal "payment_reminder_overdue", Notification.last.event_type
    end

    # ── Idempotency ───────────────────────────────────────────────────────────

    test "does not duplicate notification when called twice with the same reminder_type" do
      Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")

      assert_no_difference "Notification.count" do
        Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
      end
    end

    test "does not send duplicate email when called twice with the same reminder_type" do
      Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")

      assert_emails 0 do
        Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
      end
    end

    test "different reminder_types for the same payment are not treated as duplicates" do
      Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")

      assert_difference "Notification.count", 1 do
        Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "approaching")
      end
    end

    # ── Skip conditions ───────────────────────────────────────────────────────

    test "skips notification and email if payment is already confirmed" do
      @payment.update_column(:status, Billing::Payment.statuses[:confirmed])

      assert_no_difference "Notification.count" do
        assert_emails 0 do
          Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
        end
      end
    end

    test "skips notification and email if payment is already refunded" do
      @payment.update_column(:status, Billing::Payment.statuses[:refunded])

      assert_no_difference "Notification.count" do
        assert_emails 0 do
          Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
        end
      end
    end

    test "skips notification and email if payment is already failed" do
      @payment.update_column(:status, Billing::Payment.statuses[:failed])

      assert_no_difference "Notification.count" do
        assert_emails 0 do
          Billing::PaymentReminderJob.perform_now(@payment.id, reminder_type: "created")
        end
      end
    end

    # ── Error handling ────────────────────────────────────────────────────────

    test "discards job when payment is not found" do
      assert_nothing_raised do
        Billing::PaymentReminderJob.perform_now(-1, reminder_type: "created")
      end

      assert_equal 0, Notification.where(event_type: "payment_reminder_created").count
    end
  end
end
