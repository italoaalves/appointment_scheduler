# frozen_string_literal: true

require "test_helper"

module Billing
  class TrialEndingReminderJobTest < ActiveJob::TestCase
    setup do
      @space = Space.create!(name: "Reminder Space #{SecureRandom.hex(4)}", timezone: "UTC")
      @space.update!(owner_id: users(:manager).id)
      @subscription = Billing::TrialManager.start_trial(@space)
    end

    test "creates notification for trialing subscription within 3-day window" do
      @subscription.update_column(:trial_ends_at, 2.days.from_now)

      assert_difference "Notification.count", 1 do
        Billing::TrialEndingReminderJob.perform_now
      end

      notif = Notification.last
      assert_equal @space.owner,    notif.user
      assert_equal @subscription,   notif.notifiable
      assert_equal "trial_ending",  notif.event_type
    end

    test "skips subscription outside 3-day window" do
      @subscription.update_column(:trial_ends_at, 5.days.from_now)

      assert_no_difference "Notification.count" do
        Billing::TrialEndingReminderJob.perform_now
      end
    end

    test "skips subscription with no owner" do
      @space.update_column(:owner_id, nil)
      @subscription.update_column(:trial_ends_at, 1.day.from_now)

      assert_no_difference "Notification.count" do
        Billing::TrialEndingReminderJob.perform_now
      end
    end

    test "idempotent: running twice does not create duplicate" do
      @subscription.update_column(:trial_ends_at, 2.days.from_now)

      Billing::TrialEndingReminderJob.perform_now

      assert_no_difference "Notification.count" do
        Billing::TrialEndingReminderJob.perform_now
      end
    end

    test "skips non-trialing subscriptions" do
      @subscription.update_columns(status: Billing::Subscription.statuses[:active],
                                    trial_ends_at: 2.days.from_now)

      assert_no_difference "Notification.count" do
        Billing::TrialEndingReminderJob.perform_now
      end
    end
  end
end
