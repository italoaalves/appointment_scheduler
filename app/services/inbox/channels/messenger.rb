# frozen_string_literal: true

module Inbox
  module Channels
    class Messenger < Base
      def session_windowed?
        true
      end

      def can_send?(conversation)
        conversation.session_active?
      end

      def send_blocked_reason(conversation)
        return nil if conversation.session_active?

        I18n.t("inbox.channels.messenger.session_expired")
      end

      def send_message(conversation, body:, sent_by:)
        raise NotImplementedError, "Messenger channel not yet implemented"
      end
    end
  end
end
