# frozen_string_literal: true

module Messaging
  module Channels
    class Whatsapp < Base
      def deliver(to:, body:, subject: nil, **opts)
        phone = resolve_phone(to)
        raise Messaging::DeliveryError, "WhatsApp channel requires recipient with phone" if phone.blank?

        client = twilio_client
        raise Messaging::DeliveryError, "WhatsApp is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_WHATSAPP_FROM" unless client_configured?

        client.messages.create(
          to: "whatsapp:#{normalize_phone(phone)}",
          from: "whatsapp:#{from_number}",
          body: body
        )

        { success: true }
      end

      private

      def resolve_phone(to)
        return to.presence if to.is_a?(String)
        return to.phone if to.respond_to?(:phone)

        nil
      end

      def normalize_phone(phone)
        # Ensure E.164 format - add + if missing
        phone.to_s.strip.sub(/\A(?!\+)/, "+")
      end

      def twilio_client
        return @client if defined?(@client)

        @client = if client_configured?
          require "twilio-ruby"
          ::Twilio::REST::Client.new(account_sid, auth_token)
        end
      end

      def client_configured?
        account_sid.present? && auth_token.present? && from_number.present?
      end

      def account_sid
        @account_sid ||= Rails.application.credentials.dig(:twilio, :account_sid) || ENV["TWILIO_ACCOUNT_SID"]
      end

      def auth_token
        @auth_token ||= Rails.application.credentials.dig(:twilio, :auth_token) || ENV["TWILIO_AUTH_TOKEN"]
      end

      def from_number
        @from_number ||= Rails.application.credentials.dig(:twilio, :whatsapp_from) || ENV["TWILIO_WHATSAPP_FROM"]
      end
    end
  end
end
