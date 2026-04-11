# frozen_string_literal: true

module Billing
  class CreditsMailer < ApplicationMailer
    def fulfilled(credit_purchase:)
      @credit_purchase = credit_purchase
      @amount          = credit_purchase.amount
      @space           = credit_purchase.space
      recipient        = credit_purchase.actor || @space.owner

      with_mail_locale(recipient:, fallback_space: @space) do
        mail(
          to:      recipient.email,
          subject: I18n.t("billing.credits_mailer.fulfilled.subject", amount: @amount)
        )
      end
    end

    def failed(credit_purchase:)
      @credit_purchase = credit_purchase
      @amount          = credit_purchase.amount
      @space           = credit_purchase.space
      recipient        = credit_purchase.actor || @space.owner

      with_mail_locale(recipient:, fallback_space: @space) do
        mail(
          to:      recipient.email,
          subject: I18n.t("billing.credits_mailer.failed.subject", amount: @amount)
        )
      end
    end
  end
end
