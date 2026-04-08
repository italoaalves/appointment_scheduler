# frozen_string_literal: true

module Inbox
  class SendTemplateReopen
    Result = Struct.new(:success?, :message, :error, keyword_init: true)

    def initialize(conversation:, sent_by:, space:, template_name: nil)
      @conversation = conversation
      @sent_by = sent_by
      @space = space
      @template_name = template_name
    end

    def call
      channel = ChannelRegistry.for(@conversation.channel)
      return unsupported_result unless channel.can_send_template?(@conversation)

      template_name = @template_name.presence || channel.class.default_reengagement_template
      return template_not_configured_result if template_name.blank?

      credit_deduction = Billing::CreditManager.deduct(space: @space)
      return insufficient_credits_result unless credit_deduction[:success]

      result = channel.send_template(@conversation, template_name: template_name, sent_by: @sent_by)

      message = ConversationMessage.create!(
        conversation: @conversation,
        direction: :outbound,
        status: result[:status],
        external_message_id: result[:external_message_id],
        sent_by: @sent_by,
        credit_cost: 1,
        message_type: "template",
        metadata: { "template_name" => template_name }
      )

      update_conversation_after_template_send

      Result.new(success?: true, message: message)
    rescue => e
      Billing::CreditManager.refund(space: @space, source: credit_deduction[:source]) if credit_deduction&.dig(:success)

      failed_message = ConversationMessage.create!(
        conversation: @conversation,
        direction: :outbound,
        status: :failed,
        sent_by: @sent_by,
        credit_cost: 0,
        message_type: "template",
        metadata: { "template_name" => template_name }.compact
      )

      Rails.logger.error("[Inbox::SendTemplateReopen] #{e.class}: #{e.message}")
      Result.new(success?: false, message: failed_message, error: I18n.t("inbox.errors.send_failed"))
    end

    private

    def update_conversation_after_template_send
      attrs = {
        last_message_at: Time.current,
        last_message_body: nil,
        status: :open,
        credit_cost_total: @conversation.credit_cost_total + 1
      }
      attrs[:first_response_at] = Time.current if @conversation.first_response_at.nil?
      @conversation.update!(attrs)
    end

    def unsupported_result
      Result.new(success?: false, error: I18n.t("spaces.conversations.detail.template_not_supported"))
    end

    def template_not_configured_result
      Result.new(success?: false, error: I18n.t("spaces.conversations.detail.template_not_configured"))
    end

    def insufficient_credits_result
      Result.new(success?: false, error: I18n.t("inbox.errors.insufficient_credits"))
    end
  end
end
