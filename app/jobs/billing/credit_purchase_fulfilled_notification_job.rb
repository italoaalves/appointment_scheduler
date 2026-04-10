# frozen_string_literal: true

module Billing
  class CreditPurchaseFulfilledNotificationJob < ApplicationJob
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
        event_type: "credits_fulfilled",
        title:      I18n.t("notifications.in_app.credits_fulfilled.title", amount: purchase.amount),
        body:       I18n.t("notifications.in_app.credits_fulfilled.body",  amount: purchase.amount)
      )

      Billing::CreditsMailer.fulfilled(credit_purchase: purchase).deliver_now
    end

    private

    def already_notified?(user, purchase)
      Notification.where(
        user:       user,
        notifiable: purchase,
        event_type: "credits_fulfilled"
      ).where("created_at > ?", 24.hours.ago).exists?
    end
  end
end
