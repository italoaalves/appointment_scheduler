# frozen_string_literal: true

require "test_helper"

module Billing
  class CreditPurchaseFailedNotificationJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    setup do
      @space    = spaces(:one)
      @space.update!(owner_id: users(:manager).id) unless @space.owner_id.present?
      @purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: credit_bundles(:fifty),
        amount:        50,
        price_cents:   2500,
        status:        :failed
      )
    end

    test "creates in-app notification for the space owner" do
      assert_difference "Notification.count", 1 do
        Billing::CreditPurchaseFailedNotificationJob.perform_now(@purchase.id)
      end

      notif = Notification.last
      assert_equal @space.owner,    notif.user
      assert_equal @purchase,       notif.notifiable
      assert_equal "credits_failed", notif.event_type
    end

    test "notification title and body include the credit amount" do
      Billing::CreditPurchaseFailedNotificationJob.perform_now(@purchase.id)

      notif = Notification.last
      assert_includes notif.title, "50"
      assert_includes notif.body,  "50"
    end

    test "sends email to the space owner" do
      assert_emails 1 do
        Billing::CreditPurchaseFailedNotificationJob.perform_now(@purchase.id)
      end

      email = ActionMailer::Base.deliveries.last
      assert_equal [ @space.owner.email ], email.to
    end

    test "notifies actor instead of owner when actor is set" do
      actor = users(:manager)
      @purchase.update_column(:actor_id, actor.id)

      Billing::CreditPurchaseFailedNotificationJob.perform_now(@purchase.id)

      notif = Notification.last
      assert_equal actor, notif.user
    end

    test "is idempotent — running twice does not create duplicate notification" do
      Billing::CreditPurchaseFailedNotificationJob.perform_now(@purchase.id)

      assert_no_difference "Notification.count" do
        Billing::CreditPurchaseFailedNotificationJob.perform_now(@purchase.id)
      end
    end

    test "discards job when CreditPurchase is not found" do
      assert_nothing_raised do
        Billing::CreditPurchaseFailedNotificationJob.perform_now(-1)
      end

      assert_equal 0, Notification.where(event_type: "credits_failed").count
    end
  end
end
