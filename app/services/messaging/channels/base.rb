# frozen_string_literal: true

module Messaging
  module Channels
    class Base
      def deliver(to:, body:, subject: nil, **opts)
        raise NotImplementedError, "#{self.class} must implement #deliver"
      end
    end
  end
end
