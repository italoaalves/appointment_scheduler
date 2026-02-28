# frozen_string_literal: true

require "test_helper"

module Billing
  class CreditsLowCheckJobTest < ActiveJob::TestCase
    setup do
      @space = Space.create!(name: "Credits Space #{SecureRandom.hex(4)}", timezone: "UTC")
      @space.update!(owner_id: users(:manager).id)
      sub = Billing::TrialManager.start_trial(@space)
      # Use a plan with metered WhatsApp (not unlimited) — essential has quota 0, pro has 200
      # We want a plan where whatsapp_unlimited? is false, so use essential (quota: 0, not nil)
      # Actually we need to make sure it's not nil. essential has whatsapp_monthly_quota: 0.
      # Let's just use the pro plan which has 200, also not nil.
      @credit = Billing::MessageCredit.find_by!(space_id: @space.id)
    end

    test "creates notification when total credits <= 10 and > 0" do
      @credit.update_columns(balance: 5, monthly_quota_remaining: 3)

      assert_difference "Notification.count", 1 do
        Billing::CreditsLowCheckJob.perform_now
      end

      notif = Notification.last
      assert_equal @space.owner,  notif.user
      assert_equal @credit,       notif.notifiable
      assert_equal "credits_low", notif.event_type
      assert_includes notif.body, "8"
    end

    test "skips when total credits > 10" do
      @credit.update_columns(balance: 8, monthly_quota_remaining: 5)

      assert_no_difference "Notification.count" do
        Billing::CreditsLowCheckJob.perform_now
      end
    end

    test "skips when total credits is 0" do
      @credit.update_columns(balance: 0, monthly_quota_remaining: 0)

      assert_no_difference "Notification.count" do
        Billing::CreditsLowCheckJob.perform_now
      end
    end

    test "skips spaces with unlimited WhatsApp plan" do
      # nil quota means unlimited
      @credit.space.subscription.billing_plan.update_column(:whatsapp_monthly_quota, nil)
      @credit.update_columns(balance: 3, monthly_quota_remaining: 2)

      assert_no_difference "Notification.count" do
        Billing::CreditsLowCheckJob.perform_now
      end
    end

    test "skips when owner is nil" do
      @space.update_column(:owner_id, nil)
      @credit.update_columns(balance: 3, monthly_quota_remaining: 2)

      assert_no_difference "Notification.count" do
        Billing::CreditsLowCheckJob.perform_now
      end
    end

    test "idempotent: running twice does not create duplicate" do
      @credit.update_columns(balance: 5, monthly_quota_remaining: 3)

      Billing::CreditsLowCheckJob.perform_now

      assert_no_difference "Notification.count" do
        Billing::CreditsLowCheckJob.perform_now
      end
    end
  end
end
