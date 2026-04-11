# frozen_string_literal: true

module Billing
  class PaymentMailer < ApplicationMailer
    def reminder(payment:, reminder_type: "created")
      @payment        = payment
      @subscription   = payment.subscription
      @space          = @subscription.space
      @reminder_type  = reminder_type
      @amount         = payment.amount_cents / 100.0
      @due_date       = payment.due_date
      @invoice_url    = payment.invoice_url
      @payment_method = payment.payment_method
      recipient       = @space.owner

      with_mail_locale(recipient:, fallback_space: @space) do
        mail(
          to:      recipient.email,
          subject: I18n.t(
            "billing.payment_mailer.reminder.subjects.#{reminder_type}",
            amount:   ApplicationController.helpers.number_to_currency(@amount, unit: "R$"),
            due_date: @due_date ? I18n.l(@due_date, format: :long) : "-"
          )
        )
      end
    end
  end
end
