# frozen_string_literal: true

module Messaging
  class CustomerMessageMailer < ApplicationMailer
    def customer_message(to:, body:, subject: nil, reply_to: nil, locale: nil)
      @body = body

      with_mail_locale(locale, fallback_space: nil) do
        mail(
          to: to,
          subject: subject.presence || I18n.t("messaging.customer_message_mailer.customer_message.subject"),
          reply_to: reply_to
        )
      end
    end
  end
end
