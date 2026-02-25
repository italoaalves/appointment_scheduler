# frozen_string_literal: true

module Space
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_tenant_staff

    private

    def require_tenant_staff
      return redirect_to platform_root_path, alert: t("space.unauthorized") if current_user.super_admin?
      return if tenant_staff?

      redirect_to root_path, alert: t("space.unauthorized")
    end
  end
end
