# frozen_string_literal: true

module Platform
  class ImpersonationsController < Platform::BaseController
    def stop
      impersonated_id = session.delete(:impersonated_user_id)
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
