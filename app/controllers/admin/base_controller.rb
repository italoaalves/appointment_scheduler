# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_tenant_staff

    private

    def require_tenant_staff
      return redirect_to root_path, alert: t("admin.unauthorized") if current_user.super_admin?
      return if tenant_staff?

      redirect_to root_path, alert: t("admin.unauthorized")
    end
  end
end
