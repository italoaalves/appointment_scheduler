# frozen_string_literal: true

require "test_helper"

module Billing
  class PaymentDueReminderJobTest < ActiveJob::TestCase
    setup do
      @space = Space.create!(name: "PaymentDueReminder Space #{SecureRandom.hex(4)}", timezone: "UTC")
      Billing::TrialManager.start_trial(@space)
      @subscription = @space.reload.subscription
      @subscription.update_columns(
        payment_method:        Billing::Subscription.payment_methods[:pix],
        asaas_subscription_id: "sub_pdr_#{SecureRandom.hex(4)}"
      )
    end

    def create_payment(due_date:, payment_method: :pix, status: :pending)
      Billing::Payment.create!(
        space:            @space,
        subscription:     @subscription,
        asaas_payment_id: "pay_pdr_#{SecureRandom.hex(6)}",
        amount_cents:     9900,
        payment_method:   payment_method,
        status:           status,
        due_date:         due_date
      )
    end

    # ── Approaching (3 days out) ──────────────────────────────────────────────

    test "enqueues PaymentReminderJob for PIX payments due in exactly 3 days" do
      create_payment(due_date: 3.days.from_now.to_date)

      assert_enqueued_jobs 1, only: Billing::PaymentReminderJob do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "enqueues PaymentReminderJob for Boleto payments due in 3 days" do
      create_payment(due_date: 3.days.from_now.to_date, payment_method: :boleto)

      assert_enqueued_jobs 1, only: Billing::PaymentReminderJob do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "uses approaching reminder_type for payments due in 3 days" do
      @space.update!(owner_id: users(:manager).id)
      create_payment(due_date: 3.days.from_now.to_date)

      perform_enqueued_jobs { Billing::PaymentDueReminderJob.perform_now }

      assert_equal "payment_reminder_approaching", Notification.last&.event_type
    end

    # ── Due today ─────────────────────────────────────────────────────────────

    test "enqueues PaymentReminderJob for payments due today" do
      create_payment(due_date: Date.current)

      assert_enqueued_jobs 1, only: Billing::PaymentReminderJob do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "uses due_today reminder_type for payments due today" do
      @space.update!(owner_id: users(:manager).id)
      create_payment(due_date: Date.current)

      perform_enqueued_jobs { Billing::PaymentDueReminderJob.perform_now }

      assert_equal "payment_reminder_due_today", Notification.last&.event_type
    end

    # ── Overdue (1 day past) ──────────────────────────────────────────────────

    test "enqueues PaymentReminderJob for payments 1 day overdue" do
      create_payment(due_date: 1.day.ago.to_date)

      assert_enqueued_jobs 1, only: Billing::PaymentReminderJob do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "uses overdue reminder_type for payments 1 day overdue" do
      @space.update!(owner_id: users(:manager).id)
      create_payment(due_date: 1.day.ago.to_date)

      perform_enqueued_jobs { Billing::PaymentDueReminderJob.perform_now }

      assert_equal "payment_reminder_overdue", Notification.last&.event_type
    end

    # ── Skip conditions ───────────────────────────────────────────────────────

    test "does not enqueue reminder for confirmed payments" do
      create_payment(due_date: 3.days.from_now.to_date, status: :confirmed)

      assert_no_enqueued_jobs(only: Billing::PaymentReminderJob) do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "does not enqueue reminder for credit_card payments" do
      create_payment(due_date: 3.days.from_now.to_date, payment_method: :credit_card)

      assert_no_enqueued_jobs(only: Billing::PaymentReminderJob) do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "does not enqueue reminder for payments due in more than 3 days" do
      create_payment(due_date: 4.days.from_now.to_date)

      assert_no_enqueued_jobs(only: Billing::PaymentReminderJob) do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "does not enqueue reminder for payments 2 or more days overdue" do
      create_payment(due_date: 2.days.ago.to_date)

      assert_no_enqueued_jobs(only: Billing::PaymentReminderJob) do
        Billing::PaymentDueReminderJob.perform_now
      end
    end

    test "does not enqueue reminder for payments with no due_date" do
      create_payment(due_date: nil)

      assert_no_enqueued_jobs(only: Billing::PaymentReminderJob) do
        Billing::PaymentDueReminderJob.perform_now
      end
    end
  end
end
