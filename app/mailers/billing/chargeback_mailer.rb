# frozen_string_literal: true

module Billing
  class ChargebackMailer < ApplicationMailer
    def chargeback_alert(admin:, space:, payment:, event_name:, reason:)
      @admin      = admin
      @space      = space
      @payment    = payment
      @event_name = event_name
      @reason     = reason

      with_mail_locale(recipient: admin, fallback_space: space) do
        mail(
          to:      admin.email,
          subject: I18n.t("billing.chargeback_mailer.chargeback_alert.subject", space_name: space.name, event_name: event_name)
        )
      end
    end
  end
end
