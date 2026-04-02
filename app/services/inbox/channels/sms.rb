# frozen_string_literal: true

module Inbox
  module Channels
    class Sms < Base
      def can_send?(_conversation)
        true
      end

      def send_message(conversation, body:, sent_by:)
        raise NotImplementedError, "SMS channel not yet implemented"
      end
    end
  end
end
