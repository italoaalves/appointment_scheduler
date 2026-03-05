# frozen_string_literal: true

require "test_helper"

module Billing
  class PlanChangePaymentReminderJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    setup do
      @space        = spaces(:one)
      @space.update!(owner_id: users(:manager).id) unless @space.owner_id.present?
      @subscription = subscriptions(:one)
      @subscription.update_columns(
        space_id:       @space.id,
        payment_method: Billing::Subscription.payment_methods[:pix]
      )
      @new_plan = billing_plans(:pro)
    end

    test "creates in-app notification for the space owner" do
      assert_difference "Notification.count", 1 do
        Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)
      end

      notif = Notification.last
      assert_equal @space.owner,          notif.user
      assert_equal @subscription,         notif.notifiable
      assert_equal "plan_change_payment", notif.event_type
    end

    test "notification title and body include the plan name" do
      Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)

      notif = Notification.last
      assert_includes notif.title, I18n.t("notifications.in_app.plan_change_payment.title")
      assert_includes notif.body,  @new_plan.name
    end

    test "sends email to the space owner" do
      assert_emails 1 do
        Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)
      end

      email = ActionMailer::Base.deliveries.last
      assert_equal [ @space.owner.email ], email.to
      assert_includes email.subject, @new_plan.name
    end

    test "email body references PIX when payment method is PIX" do
      Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)

      email = ActionMailer::Base.deliveries.last
      assert_includes email.text_part.body.decoded, "PIX"
    end

    test "email body references Boleto when payment method is Boleto" do
      @subscription.update_column(:payment_method, Billing::Subscription.payment_methods[:boleto])

      Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)

      email = ActionMailer::Base.deliveries.last
      assert_includes email.text_part.body.decoded, "boleto"
    end

    test "is idempotent — running twice does not create duplicate notification" do
      Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)

      assert_no_difference "Notification.count" do
        Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)
      end
    end

    test "is idempotent — running twice sends only one email" do
      Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)

      assert_emails 0 do
        Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, @new_plan.id)
      end
    end

    test "discards job when subscription is not found" do
      assert_nothing_raised do
        Billing::PlanChangePaymentReminderJob.perform_now(-1, @new_plan.id)
      end

      assert_equal 0, Notification.where(event_type: "plan_change_payment").count
    end

    test "discards job when plan is not found" do
      assert_nothing_raised do
        Billing::PlanChangePaymentReminderJob.perform_now(@subscription.id, -1)
      end

      assert_equal 0, Notification.where(event_type: "plan_change_payment").count
    end
  end
end
