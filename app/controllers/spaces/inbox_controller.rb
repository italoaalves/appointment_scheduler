# frozen_string_literal: true

module Spaces
  class InboxController < Spaces::BaseController
    before_action :require_whatsapp_feature
    before_action :set_conversation, only: [ :show, :reply ]

    def index
      @conversations = current_tenant.whatsapp_conversations
        .recent
        .includes(:whatsapp_messages)
        .page(params[:page])
    end

    def show
      @messages = @conversation.whatsapp_messages.chronological
      @conversation.update!(unread: false)
      mark_latest_inbound_as_read
    end

    def reply
      body = params[:body]&.strip
      if body.blank?
        redirect_to spaces_inbox_path(@conversation), alert: t(".body_required")
        return
      end

      unless @conversation.session_active?
        redirect_to spaces_inbox_path(@conversation), alert: t(".session_expired")
        return
      end

      client = Whatsapp::Client.new
      result = client.send_text(to: @conversation.customer_phone, body: body)

      wamid = result.dig("messages", 0, "id")
      @conversation.whatsapp_messages.create!(
        wamid: wamid,
        direction: :outbound,
        body: body,
        message_type: "text",
        status: :pending,
        sent_by: current_user
      )
      @conversation.update!(last_message_at: Time.current)

      redirect_to spaces_inbox_path(@conversation), status: :see_other
    rescue Whatsapp::Client::ApiError => e
      Rails.logger.error("[Inbox] Reply failed: #{e.message}")
      redirect_to spaces_inbox_path(@conversation), alert: t(".delivery_failed"), status: :see_other
    end

    private

    def set_conversation
      @conversation = current_tenant.whatsapp_conversations.find(params[:id])
    end

    def mark_latest_inbound_as_read
      latest_inbound = @conversation.whatsapp_messages.inbound.last
      return unless latest_inbound&.wamid

      Whatsapp::Client.new.mark_as_read(message_id: latest_inbound.wamid)
    rescue Whatsapp::Client::ApiError => e
      Rails.logger.warn("[Inbox] mark_as_read failed: #{e.message}")
    end

    def require_whatsapp_feature
      unless Billing::PlanEnforcer.can?(current_tenant, :send_whatsapp)
        redirect_to settings_billing_path, alert: t("billing.feature_not_available")
      end
    end
  end
end
