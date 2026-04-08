# frozen_string_literal: true

module Spaces
  class ConversationsController < BaseController
    before_action :require_inbox_access
    before_action :require_write_inbox, only: [ :reply, :reopen_with_template, :update, :assign, :resolve, :reopen ]
    before_action :set_conversation, only: [ :show, :reply, :reopen_with_template, :update, :assign, :resolve, :reopen ]

    def index
      @space_users = current_tenant.users.order(:name)
      @conversations = filtered_conversations
        .includes(:customer, :assigned_to, :conversation_messages)
        .order(last_message_at: :desc)
        .page(params[:page])

      return unless params[:id].present?

      @conversation = current_tenant.conversations
        .includes(:customer, :assigned_to, :conversation_messages)
        .find(params[:id])
      @channel = Inbox::ChannelRegistry.for(@conversation.channel)
      @can_write_inbox = PermissionService.can?(user: current_user, permission: "write_inbox", space: current_tenant)
    end

    def show
      @messages = @conversation.conversation_messages.chronological
      @channel = Inbox::ChannelRegistry.for(@conversation.channel)
      @metrics = Inbox::ComputeMetrics.new(@conversation)
      @can_write_inbox = PermissionService.can?(user: current_user, permission: "write_inbox", space: current_tenant)
      mark_as_read
    end

    def reply
      body = reply_params[:body]&.strip

      if body.blank?
        handle_detail_response(success: false, message: t("spaces.conversations.detail.body_required"), type: :alert)
        return
      end

      result = Inbox::SendReply.new(
        conversation: @conversation,
        body: body,
        sent_by: current_user,
        space: current_tenant
      ).call

      if result.success?
        handle_detail_response(success: true)
      else
        @conversation = result.message&.conversation || @conversation
        handle_detail_response(success: false, message: result.error, type: :alert)
      end
    end

    def reopen_with_template
      result = Inbox::SendTemplateReopen.new(
        conversation: @conversation,
        sent_by: current_user,
        space: current_tenant,
        template_name: params[:template_name]
      ).call

      if result.success?
        handle_detail_response(success: true, message: t("spaces.conversations.detail.template_sent"), type: :notice)
      else
        @conversation = result.message&.conversation || @conversation
        handle_detail_response(success: false, message: result.error, type: :alert)
      end
    end

    def update
      if @conversation.update(update_params)
        redirect_to spaces_inbox_path(@conversation), status: :see_other
      else
        redirect_to spaces_inbox_path(@conversation),
                    alert: t("spaces.conversations.update_failed"), status: :see_other
      end
    rescue ArgumentError
      redirect_to spaces_inbox_path(@conversation),
                  alert: t("spaces.conversations.update_failed"), status: :see_other
    end

    def assign
      @conversation.update!(assigned_to_id: assign_params[:assigned_to_id])
      redirect_to spaces_inbox_path(@conversation), status: :see_other
    end

    def resolve
      @conversation.update!(status: :resolved)
      redirect_to spaces_inbox_index_path, status: :see_other
    end

    def reopen
      @conversation.update!(status: :needs_reply)
      redirect_to spaces_inbox_path(@conversation), status: :see_other
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
      unless PermissionService.can?(user: current_user, permission: "write_inbox", space: current_tenant)
        redirect_to spaces_inbox_index_path, alert: t("inbox.write_denied")
      end
    end

    def filtered_conversations
      scope = current_tenant.conversations

      # Tab-based filtering (replaces old all/status checkbox)
      # Support both new 'tab' param and legacy 'status' param for backward compatibility
      tab = params[:tab].presence || (params[:status].presence if params[:status].present? && params[:status] != "all") || "needs_reply"
      case tab
      when "needs_reply"
        scope = scope.where(status: [ :needs_reply ])
      when "open"
        scope = scope.where(status: [ :open, :pending ])
      when "all"
        # "all" tab: no status filter
      else
        # Legacy: filter by specific status if tab is a status value
        scope = scope.where(status: tab.to_sym)
      end

      # Full-text search across contact name and identifier
      if params[:q].present?
        q = "%#{params[:q].strip}%"
        scope = scope.where("contact_name ILIKE ? OR contact_identifier ILIKE ?", q, q)
      end

      # Advanced filters (from the hidden drawer)
      scope = scope.where(channel: params[:channel]) if params[:channel].present?
      scope = scope.where(priority: params[:priority]) if params[:priority].present?
      scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
      if params[:assigned_to].present?
        if params[:assigned_to] == "none"
          scope = scope.where(assigned_to_id: nil)
        else
          scope = scope.where(assigned_to_id: params[:assigned_to])
        end
      end
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

    def handle_detail_response(success:, message: nil, type: nil)
      load_detail_state
      standalone = ActiveModel::Type::Boolean.new.cast(params[:standalone])

      respond_to do |format|
        format.turbo_stream do
          streams = [
            turbo_stream.replace(
              "conversation_detail",
              partial: "spaces/conversations/detail_frame",
              locals: { conversation: @conversation, standalone: standalone, channel: @channel, can_write_inbox: @can_write_inbox }
            )
          ]

          if message.present? && type.present?
            streams << turbo_stream.prepend("flash_messages", partial: "shared/flash_stream", locals: { type: type, message: message })
          end

          render turbo_stream: streams
        end

        format.html do
          redirect_options = { status: :see_other }
          redirect_options[type] = message if message.present? && type.present?
          redirect_to spaces_inbox_path(@conversation), **redirect_options
        end
      end
    end

    def load_detail_state
      @messages = @conversation.conversation_messages.chronological
      @channel = Inbox::ChannelRegistry.for(@conversation.channel)
      @metrics = Inbox::ComputeMetrics.new(@conversation)
      @can_write_inbox = PermissionService.can?(user: current_user, permission: "write_inbox", space: current_tenant)
    end
  end
end
