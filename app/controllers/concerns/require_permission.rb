# frozen_string_literal: true

module RequirePermission
  extend ActiveSupport::Concern

  class_methods do
    def require_permission(permission, only: nil, except: nil, redirect_to: nil)
      options = { only: only, except: except }.compact
      before_action(options) { check_permission!(permission, redirect_path: redirect_to) }
    end
  end

  private

  def check_permission!(permission, redirect_path: nil)
    return if current_user&.can?(permission, space: current_tenant)

    AuditLogs::EventLogger.call(
      event_type: "authorization.permission_denied",
      actor: audit_actor,
      space: current_tenant,
      request: request,
      impersonated: impersonating?,
      metadata: audit_context_metadata.merge(permission: permission.to_s)
    )

    path = redirect_path.is_a?(Symbol) ? send(redirect_path) : redirect_path
    redirect_to path || root_path, alert: t("space.unauthorized")
  end
end
