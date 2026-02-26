# frozen_string_literal: true

module Spaces
  # Base controller for space owner and team member workflows.
  # All data is scoped to current_tenant (current_user.space).
  # Super admins are redirected to platform; space staff must have access_space_dashboard.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_space_staff

    private

    def require_space_staff
      return redirect_to platform_root_path, alert: t("space.unauthorized") if current_user.super_admin?
      return if tenant_staff?

      redirect_to root_path, alert: t("space.unauthorized")
    end
  end
end
