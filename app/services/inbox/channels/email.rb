# frozen_string_literal: true

module Inbox
  module Channels
    class Email < Base
      def can_send?(_conversation)
        true
      end

      def send_message(conversation, body:, sent_by:)
        raise NotImplementedError, "Email channel not yet implemented"
      end
    end
  end
end
