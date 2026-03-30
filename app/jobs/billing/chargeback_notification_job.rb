# frozen_string_literal: true

module Billing
  class ChargebackNotificationJob < ApplicationJob
    queue_as :default

    def perform(payment_id, event_name, reason)
      # Unscoped lookup is intentional — background jobs don't set Current.space.
      payment = Billing::Payment.find(payment_id)
      space   = payment.space

      notification_event_type = "notification.#{event_name.downcase}"
      return if Billing::BillingEvent.where(event_type: notification_event_type)
                                     .where("metadata->>? = ?", "asaas_payment_id", payment.asaas_payment_id)
                                     .exists?

      Billing::BillingEvent.create!(
        space_id:        space.id,
        subscription_id: payment.subscription_id,
        event_type:      notification_event_type,
        metadata:        {
          asaas_payment_id: payment.asaas_payment_id,
          chargeback_event: event_name
        }
      )

      User.where(system_role: :super_admin).find_each do |admin|
        Billing::ChargebackMailer.chargeback_alert(
          admin:      admin,
          space:      space,
          payment:    payment,
          event_name: event_name,
          reason:     reason
        ).deliver_later
      end
    end
  end
end
