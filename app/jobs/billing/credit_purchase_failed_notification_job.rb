# frozen_string_literal: true

module Billing
  class CreditPurchaseFailedNotificationJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound, report: true

    def perform(credit_purchase_id)
      purchase  = Billing::CreditPurchase.find(credit_purchase_id)
      recipient = purchase.actor || purchase.space.owner

      return if recipient.nil?
      return if already_notified?(recipient, purchase)

      Notification.create!(
        user:       recipient,
        notifiable: purchase,
        event_type: "credits_failed",
        title:      I18n.t("notifications.in_app.credits_failed.title", amount: purchase.amount),
        body:       I18n.t("notifications.in_app.credits_failed.body",  amount: purchase.amount)
      )

      Billing::CreditsMailer.failed(credit_purchase: purchase).deliver_now
    end

    private

    def already_notified?(user, purchase)
      Notification.where(
        user:       user,
        notifiable: purchase,
        event_type: "credits_failed"
      ).where("created_at > ?", 24.hours.ago).exists?
    end
  end
end
