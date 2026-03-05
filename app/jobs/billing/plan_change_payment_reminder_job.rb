# frozen_string_literal: true

module Billing
  class PlanChangePaymentReminderJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(subscription_id, new_plan_id)
      subscription = Billing::Subscription.find(subscription_id)
      new_plan     = Billing::Plan.find(new_plan_id)
      recipient    = subscription.space.owner

      return if recipient.nil?
      return if already_notified?(recipient, subscription)

      payment_method = subscription.payment_method

      Notification.create!(
        user:       recipient,
        notifiable: subscription,
        event_type: "plan_change_payment",
        title:      I18n.t("notifications.in_app.plan_change_payment.title"),
        body:       I18n.t(
          "notifications.in_app.plan_change_payment.body",
          plan_name:      new_plan.name,
          payment_method: I18n.t("billing.payment_methods.#{payment_method}")
        )
      )

      Billing::SubscriptionMailer
        .plan_change_payment_reminder(subscription: subscription, new_plan: new_plan)
        .deliver_now
    end

    private

    def already_notified?(user, subscription)
      Notification.where(
        user:       user,
        notifiable: subscription,
        event_type: "plan_change_payment"
      ).where("created_at > ?", 24.hours.ago).exists?
    end
  end
end
