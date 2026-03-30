# frozen_string_literal: true

require "test_helper"

module Billing
  class ExpireTrialsJobTest < ActiveSupport::TestCase
    setup do
      @space = spaces(:one)
    end

    test "expires trialing subscriptions past their trial_ends_at" do
      sub = subscriptions(:one)
      sub.update!(trial_ends_at: 1.day.ago)

      Billing::ExpireTrialsJob.new.perform

      assert sub.reload.expired?,
             "Expected subscription to be expired but was #{sub.status}"
    end

    test "logs a trial.expired BillingEvent when expiring" do
      sub = subscriptions(:one)
      sub.update!(trial_ends_at: 2.days.ago)

      assert_difference "Billing::BillingEvent.count", 1 do
        Billing::ExpireTrialsJob.new.perform
      end

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "trial.expired", event.event_type
    end

    test "does not expire trialing subscriptions with future trial_ends_at" do
      sub = subscriptions(:one)  # trial_ends_at: 14.days.from_now, status: trialing

      Billing::ExpireTrialsJob.new.perform

      assert sub.reload.trialing?,
             "Expected subscription to still be trialing"
    end

    test "does not expire active subscriptions" do
      sub = subscriptions(:two)  # status: active

      Billing::ExpireTrialsJob.new.perform

      assert sub.reload.active?,
             "Active subscription should not be expired by job"
    end

    # ── Task 77: stale pending_payment expiry ─────────────────────────────────

    test "expires pending_payment subscription older than 7 days" do
      sub = subscriptions(:one)
      sub.update_columns(status: Billing::Subscription.statuses[:pending_payment],
                         created_at: 8.days.ago)

      Billing::ExpireTrialsJob.new.perform

      assert sub.reload.expired?
    end

    test "logs subscription.expired BillingEvent when pending_payment subscription expires" do
      sub = subscriptions(:one)
      sub.update_columns(status: Billing::Subscription.statuses[:pending_payment],
                         created_at: 8.days.ago)

      assert_difference "Billing::BillingEvent.count", 1 do
        Billing::ExpireTrialsJob.new.perform
      end

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "subscription.expired", event.event_type
      assert_equal "pending_payment_timeout", event.metadata["reason"]
    end

    test "does not expire pending_payment subscription younger than 7 days" do
      sub = subscriptions(:one)
      sub.update_columns(status: Billing::Subscription.statuses[:pending_payment],
                         created_at: 3.days.ago)

      Billing::ExpireTrialsJob.new.perform

      assert sub.reload.pending_payment?
    end
  end
end
