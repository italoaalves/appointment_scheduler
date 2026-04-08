# frozen_string_literal: true

module Inbox
  class SendReply
    Result = Struct.new(:success?, :message, :error, keyword_init: true)

    def initialize(conversation:, body:, sent_by:, space:)
      @conversation = conversation
      @body = body
      @sent_by = sent_by
      @space = space
    end

    def call
      channel = ChannelRegistry.for(@conversation.channel)
      credit_deduction = nil

      unless channel.can_send?(@conversation)
        return Result.new(success?: false, error: channel.send_blocked_reason(@conversation))
      end

      cost = channel.send_cost(@conversation)

      if cost > 0
        credit_deduction = Billing::CreditManager.deduct(space: @space)
        unless credit_deduction[:success]
          return Result.new(success?: false, error: I18n.t("inbox.errors.insufficient_credits"))
        end
      end

      result = channel.send_message(@conversation, body: @body, sent_by: @sent_by)

      msg = ConversationMessage.create!(
        conversation: @conversation,
        direction: :outbound,
        body: @body,
        status: result[:status],
        external_message_id: result[:external_message_id],
        sent_by: @sent_by,
        credit_cost: cost
      )

      update_conversation_after_reply(msg, cost)

      Result.new(success?: true, message: msg)
    rescue => e
      Billing::CreditManager.refund(space: @space, source: credit_deduction[:source]) if credit_deduction&.dig(:success)

      failed_message = ConversationMessage.create!(
        conversation: @conversation,
        direction: :outbound,
        body: @body,
        status: :failed,
        sent_by: @sent_by,
        credit_cost: 0
      )

      Rails.logger.error("[Inbox::SendReply] #{e.class}: #{e.message}")
      Result.new(success?: false, message: failed_message, error: I18n.t("inbox.errors.send_failed"))
    end

    private

    def update_conversation_after_reply(msg, cost)
      attrs = {
        last_message_at: msg.created_at,
        last_message_body: @body.truncate(120),
        status: :open,
        credit_cost_total: @conversation.credit_cost_total + cost
      }
      attrs[:first_response_at] = msg.created_at if @conversation.first_response_at.nil?
      @conversation.update!(attrs)
    end
  end
end
