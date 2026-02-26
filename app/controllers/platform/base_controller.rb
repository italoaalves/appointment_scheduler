# frozen_string_literal: true

module Platform
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_not_impersonating, if: -> { impersonating? && !is_impersonations_controller? }
    before_action :require_platform_admin

    private

    def require_platform_admin
      return if real_current_user&.super_admin?

      redirect_to root_path, alert: t("platform.unauthorized")
    end

    def ensure_not_impersonating
      redirect_to root_path, alert: t("platform.impersonation.stop_first")
    end

    def is_impersonations_controller?
      controller_name == "impersonations"
    end
  end
end
