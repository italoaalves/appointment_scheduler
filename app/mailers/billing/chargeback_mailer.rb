# frozen_string_literal: true

module Billing
  class ChargebackMailer < ApplicationMailer
    def chargeback_alert(admin:, space:, payment:, event_name:, reason:)
      @admin      = admin
      @space      = space
      @payment    = payment
      @event_name = event_name
      @reason     = reason

      mail(
        to:      admin.email,
        subject: "[ALERT] Chargeback — #{space.name} — #{event_name}"
      )
    end
  end
end
