# frozen_string_literal: true

module Platform
  class ImpersonationsController < Platform::BaseController
    def stop
      impersonated_id = session.delete(:impersonated_user_id)
      impersonated_user = User.find_by(id: impersonated_id)
      AuditLogs::EventLogger.call(
        event_type: "auth.impersonation_stopped",
        actor: real_current_user,
        space: impersonated_user&.space,
        subject: impersonated_user || { name: "User #{impersonated_id}" },
        request: request,
        metadata: audit_context_metadata
      )
      Rails.logger.info(
        "[IMPERSONATION_STOP] admin_id=#{real_current_user.id} " \
        "admin_email=#{real_current_user.email} " \
        "impersonated_id=#{impersonated_id} " \
        "at=#{Time.current.iso8601}"
      )
      redirect_to platform_root_path, notice: t("platform.impersonation.stopped")
    end
  end
end
