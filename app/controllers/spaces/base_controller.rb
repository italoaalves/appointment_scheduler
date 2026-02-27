# frozen_string_literal: true

module Spaces
  # Base controller for space owner and team member workflows.
  # All data is scoped to current_tenant (current_user.space).
  # Super admins are redirected to platform; space staff must have access_space_dashboard.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_space_staff
    before_action :set_current_space

    include Billing::RequireActiveSubscription

    private

    def set_current_space
      Current.space        = current_tenant
      Current.subscription = current_tenant&.subscription
    end

    def require_space_staff
      return redirect_to platform_root_path, alert: t("space.unauthorized") if current_user.super_admin?
      return if tenant_staff?

      redirect_to root_path, alert: t("space.unauthorized")
    end
  end
end
