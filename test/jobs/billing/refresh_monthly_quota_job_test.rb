# frozen_string_literal: true

require "test_helper"

module Billing
  class RefreshMonthlyQuotaJobTest < ActiveSupport::TestCase
    setup do
      @subscription = subscriptions(:two)  # plan_id: "pro", status: active
      @space        = @subscription.space
      # Ensure a MessageCredit exists (no quota_refreshed_at → eligible for refresh)
      @credit = Billing::MessageCredit.find_or_create_by!(space: @space) do |c|
        c.balance                  = 0
        c.monthly_quota_remaining  = 0
      end
      @credit.update!(quota_refreshed_at: nil)
      @subscription.update!(current_period_start: 1.day.ago, current_period_end: 29.days.from_now)
    end

    test "refreshes monthly_quota_remaining for active subscription at new billing period" do
      Billing::RefreshMonthlyQuotaJob.new.perform

      @credit.reload
      assert_equal billing_plans(:pro).whatsapp_monthly_quota, @credit.monthly_quota_remaining
    end

    test "sets quota_refreshed_at to current time on refresh" do
      freeze_time do
        Billing::RefreshMonthlyQuotaJob.new.perform

        @credit.reload
        assert_equal Time.current, @credit.quota_refreshed_at
      end
    end

    test "logs a credits.quota_refreshed BillingEvent on refresh" do
      assert_difference "Billing::BillingEvent.count", 1 do
        Billing::RefreshMonthlyQuotaJob.new.perform
      end

      event = Billing::BillingEvent.order(:created_at).last
      assert_equal "credits.quota_refreshed", event.event_type
      assert_equal billing_plans(:pro).whatsapp_monthly_quota, event.metadata["quota"]
    end

    test "does not refresh when quota_refreshed_at is within the current billing period" do
      @credit.update!(
        monthly_quota_remaining: 999,
        quota_refreshed_at:      @subscription.current_period_start + 1.hour
      )

      Billing::RefreshMonthlyQuotaJob.new.perform

      @credit.reload
      assert_equal 999, @credit.monthly_quota_remaining,
                   "Quota should not be overwritten within the same billing period"
    end

    test "does not refresh subscriptions without a MessageCredit record" do
      @credit.delete

      assert_nothing_raised { Billing::RefreshMonthlyQuotaJob.new.perform }
    end

    test "does not process trialing subscriptions" do
      trialing = subscriptions(:one)
      credit   = Billing::MessageCredit.find_or_create_by!(space: trialing.space) do |c|
        c.balance = 0; c.monthly_quota_remaining = 0
      end
      credit.update!(monthly_quota_remaining: 0, quota_refreshed_at: nil)
      trialing.update!(current_period_start: 1.day.ago)

      Billing::RefreshMonthlyQuotaJob.new.perform

      credit.reload
      assert_equal 0, credit.monthly_quota_remaining,
                   "Trialing subscription quota should not be refreshed"
    end
  end
end
