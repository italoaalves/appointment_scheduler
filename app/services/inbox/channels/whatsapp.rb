# frozen_string_literal: true

module Inbox
  module Channels
    class Whatsapp < Base
      def session_windowed?
        true
      end

      def can_send?(conversation)
        conversation.session_active?
      end

      def send_cost(conversation)
        conversation.session_active? ? 0 : 1
      end

      def send_blocked_reason(conversation)
        return nil if conversation.session_active?

        I18n.t("inbox.channels.whatsapp.session_expired")
      end

      def send_message(conversation, body:, sent_by:)
        client = ::Whatsapp::Client.for_space(conversation.space)
        result = client.send_text(to: conversation.contact_identifier, body: body)
        wamid = result.dig("messages", 0, "id")
        { external_message_id: wamid, status: :pending }
      end
    end
  end
end
