# frozen_string_literal: true

require "test_helper"

module Notifications
  class BillingNotifierTest < ActiveSupport::TestCase
    setup do
      @user         = users(:manager)
      @subscription = subscriptions(:one)
    end

    test "creates notification with correct fields" do
      assert_difference "Notification.count", 1 do
        Notifications::BillingNotifier.notify(
          event_type: :subscription_expired,
          user:       @user,
          notifiable: @subscription
        )
      end

      notif = Notification.last
      assert_equal @user,                   notif.user
      assert_equal @subscription,           notif.notifiable
      assert_equal "subscription_expired",  notif.event_type
      assert notif.title.present?
      assert notif.body.present?
      assert_not notif.read?
    end

    test "interpolates body params" do
      Notifications::BillingNotifier.notify(
        event_type: :trial_ending,
        user:       @user,
        notifiable: @subscription,
        params:     { days: 3 }
      )

      assert_includes Notification.last.body, "3"
    end

    test "skips when user is nil" do
      assert_no_difference "Notification.count" do
        Notifications::BillingNotifier.notify(
          event_type: :subscription_expired,
          user:       nil,
          notifiable: @subscription
        )
      end
    end

    test "dedup: second call within 24h does not create duplicate" do
      Notifications::BillingNotifier.notify(
        event_type: :subscription_expired,
        user:       @user,
        notifiable: @subscription
      )

      assert_no_difference "Notification.count" do
        Notifications::BillingNotifier.notify(
          event_type: :subscription_expired,
          user:       @user,
          notifiable: @subscription
        )
      end
    end

    test "dedup: call after 24h creates a new notification" do
      Notifications::BillingNotifier.notify(
        event_type: :subscription_expired,
        user:       @user,
        notifiable: @subscription
      )
      Notification.last.update_column(:created_at, 25.hours.ago)

      assert_difference "Notification.count", 1 do
        Notifications::BillingNotifier.notify(
          event_type: :subscription_expired,
          user:       @user,
          notifiable: @subscription
        )
      end
    end

    test "logs error and does not raise on RecordInvalid" do
      Notification.stub(:create!, ->(*) { raise ActiveRecord::RecordInvalid }) do
        assert_nothing_raised do
          Notifications::BillingNotifier.notify(
            event_type: :subscription_expired,
            user:       @user,
            notifiable: @subscription
          )
        end
      end
    end
  end
end
