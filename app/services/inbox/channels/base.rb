# frozen_string_literal: true

module Inbox
  module Channels
    class Base
      # Can the team send a free-form text message right now?
      def can_send?(conversation)
        raise NotImplementedError, "#{self.class}#can_send? not implemented"
      end

      # Send a text message. Returns { external_message_id:, status: }.
      def send_message(conversation, body:, sent_by:)
        raise NotImplementedError, "#{self.class}#send_message not implemented"
      end

      # Does this channel have a session window that expires?
      def session_windowed?
        false
      end

      # Credits to deduct for sending one message (0 = free).
      def send_cost(conversation)
        0
      end

      # Human-readable reason why sending is blocked, or nil if allowed.
      def send_blocked_reason(conversation)
        nil
      end
    end
  end
end
