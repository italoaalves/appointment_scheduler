# frozen_string_literal: true

module Platform
  class ImpersonationsController < Platform::BaseController
    def stop
      session.delete(:impersonated_user_id)
      redirect_to platform_root_path, notice: t("platform.impersonation.stopped")
    end
  end
end
