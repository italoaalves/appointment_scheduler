# frozen_string_literal: true

module Messaging
  module Channels
    class Email < Base
      def deliver(to:, body:, subject: nil, reply_to: nil, **opts)
        address = resolve_email(to)
        raise Messaging::DeliveryError, "Email channel requires recipient with email" if address.blank?

        Messaging::CustomerMessageMailer.customer_message(
          to: address,
          body: body,
          subject: subject.presence || "Message",
          reply_to: reply_to
        ).deliver_now

        { success: true }
      end

      private

      def resolve_email(to)
        return to.presence if to.is_a?(String)
        return to.email if to.respond_to?(:email)

        nil
      end
    end
  end
end
