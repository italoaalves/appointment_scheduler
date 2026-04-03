# frozen_string_literal: true

module Spaces
  class ConversationsController < BaseController
    before_action :require_inbox_access
    before_action :require_write_inbox, only: [ :reply, :update, :assign, :resolve, :reopen ]
    before_action :set_conversation, only: [ :show, :reply, :update, :assign, :resolve, :reopen ]

    def index
      @conversations = filtered_conversations
        .includes(:customer, :assigned_to, :conversation_messages)
        .order(last_message_at: :desc)
        .page(params[:page])

      # Set the current conversation for detail view if specified
      @conversation = current_tenant.conversations.find(params[:id]) if params[:id].present?
    end

    def show
      @messages = @conversation.conversation_messages.chronological
      @channel = Inbox::ChannelRegistry.for(@conversation.channel)
      @metrics = Inbox::ComputeMetrics.new(@conversation)
      mark_as_read
    end

    def reply
      result = Inbox::SendReply.new(
        conversation: @conversation,
        body: reply_params[:body],
        sent_by: current_user,
        space: current_tenant
      ).call

      if result.success?
        redirect_to spaces_conversation_path(@conversation), status: :see_other
      else
        redirect_to spaces_conversation_path(@conversation),
                    alert: result.error, status: :see_other
      end
    end

    def update
      if @conversation.update(update_params)
        redirect_to spaces_conversation_path(@conversation), status: :see_other
      else
        redirect_to spaces_conversation_path(@conversation),
                    alert: t("spaces.conversations.update_failed"), status: :see_other
      end
    end

    def assign
      @conversation.update!(assigned_to_id: assign_params[:assigned_to_id])
      redirect_to spaces_conversation_path(@conversation), status: :see_other
    end

    def resolve
      @conversation.update!(status: :resolved)
      redirect_to spaces_conversations_path, status: :see_other
    end

    def reopen
      @conversation.update!(status: :needs_reply)
      redirect_to spaces_conversation_path(@conversation), status: :see_other
    end

    private

    def set_conversation
      @conversation = current_tenant.conversations.find(params[:id])
    end

    def require_inbox_access
      unless Billing::PlanEnforcer.can?(current_tenant, :access_inbox)
        redirect_to settings_billing_path, alert: t("inbox.access_denied")
      end
    end

    def require_write_inbox
      unless PermissionService.can?(current_user, current_tenant, "write_inbox")
        redirect_to spaces_conversations_path, alert: t("inbox.write_denied")
      end
    end

    def filtered_conversations
      scope = current_tenant.conversations

      # Default: hide automated conversations
      if params[:all].blank?
        scope = scope.where(status: [ :needs_reply, :open, :pending ])
      end

      scope = scope.where(channel: params[:channel]) if params[:channel].present?
      scope = scope.where(status: params[:status]) if params[:status].present? && params[:all].present?
      scope = scope.where(priority: params[:priority]) if params[:priority].present?
      scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
      scope = scope.where(assigned_to_id: params[:assigned_to]) if params[:assigned_to].present? && params[:assigned_to] != "none"
      scope = scope.where(assigned_to_id: nil) if params[:assigned_to] == "none"
      scope = scope.where(sla_breached: true) if params[:sla_breached] == "true"
      scope = scope.where(unread: true) if params[:unread] == "true"

      if params[:since].present? && params[:until].present?
        scope = scope.where(last_message_at: params[:since]..params[:until])
      end

      scope
    end

    def mark_as_read
      @conversation.update_column(:unread, false) if @conversation.unread?
    end

    def reply_params
      params.require(:reply).permit(:body)
    end

    def update_params
      params.require(:conversation).permit(:priority, :status)
    end

    def assign_params
      params.require(:conversation).permit(:assigned_to_id)
    end
  end
end
