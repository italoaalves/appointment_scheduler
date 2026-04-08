# frozen_string_literal: true

module Platform
  class AuditLogsController < Platform::BaseController
    def index
      @spaces = Space.order(:name)
      @event_types = AuditLog.distinct.order(:event_type).pluck(:event_type)
      @audit_logs = filtered_audit_logs.includes(:actor, :space).ordered.page(params[:page]).per(50)
    end

    private

    def filtered_audit_logs
      scope = AuditLog.all
      scope = scope.where(space_id: params[:space_id]) if params[:space_id].present?
      scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?
      scope = scope.where(id: AuditLog.matching_subject(params[:query]).select(:id)) if params[:query].present?
      scope
    end
  end
end
