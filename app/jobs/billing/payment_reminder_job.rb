# frozen_string_literal: true

module Billing
  class PaymentReminderJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound, report: true

    def perform(payment_id, reminder_type: "created")
      payment      = Billing::Payment.find(payment_id)
      return if payment.confirmed? || payment.refunded? || payment.failed?

      subscription = payment.subscription
      recipient    = subscription.space.owner
      return if recipient.nil?

      event_type = "payment_reminder_#{reminder_type}"
      return if already_notified?(recipient, payment, event_type)

      Notification.create!(
        user:       recipient,
        notifiable: payment,
        event_type: event_type,
        title:      I18n.t("notifications.in_app.#{event_type}.title"),
        body:       I18n.t(
          "notifications.in_app.#{event_type}.body",
          amount:         format_amount(payment.amount_cents),
          payment_method: I18n.t("billing.payment_methods.#{payment.payment_method}"),
          due_date:       payment.due_date&.strftime("%d/%m/%Y") || "-"
        )
      )

      Billing::PaymentMailer.reminder(payment: payment, reminder_type: reminder_type).deliver_now
    end

    private

    def already_notified?(user, payment, event_type)
      Notification.where(
        user:       user,
        notifiable: payment,
        event_type: event_type
      ).where("created_at > ?", 24.hours.ago).exists?
    end

    def format_amount(amount_cents)
      "R$#{format('%.2f', amount_cents / 100.0)}"
    end
  end
end
