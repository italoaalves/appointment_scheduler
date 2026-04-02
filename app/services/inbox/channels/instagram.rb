# frozen_string_literal: true

module Inbox
  module Channels
    class Instagram < Base
      def session_windowed?
        true
      end

      def can_send?(conversation)
        conversation.session_active?
      end

      def send_blocked_reason(conversation)
        return nil if conversation.session_active?

        I18n.t("inbox.channels.instagram.session_expired")
      end

      def send_message(conversation, body:, sent_by:)
        raise NotImplementedError, "Instagram channel not yet implemented"
      end
    end
  end
end
