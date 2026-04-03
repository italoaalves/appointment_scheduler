# frozen_string_literal: true

module Inbox
  class ComputeMetrics
    def initialize(conversation)
      @conversation = conversation
      @messages = conversation.conversation_messages.order(:created_at)
    end

    def first_response_time
      return nil unless @conversation.first_response_at
      @conversation.first_response_at - @conversation.created_at
    end

    def avg_team_reply_time
      compute_avg_reply_time(:outbound)
    end

    def avg_customer_reply_time
      compute_avg_reply_time(:inbound)
    end

    private

    def compute_avg_reply_time(reply_direction)
      pairs = []
      last_opposite = nil

      @messages.each do |msg|
        if msg.direction == reply_direction.to_s && last_opposite
          pairs << (msg.created_at - last_opposite)
          last_opposite = nil
        elsif msg.direction != reply_direction.to_s
          last_opposite = msg.created_at
        end
      end

      return nil if pairs.empty?
      pairs.sum / pairs.size
    end
  end
end
