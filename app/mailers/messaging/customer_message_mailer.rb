# frozen_string_literal: true

module Messaging
  class CustomerMessageMailer < ApplicationMailer
    def customer_message(to:, body:, subject: nil, reply_to: nil)
      @body = body
      mail(
        to: to,
        subject: subject.presence || "Message",
        reply_to: reply_to
      )
    end
  end
end
