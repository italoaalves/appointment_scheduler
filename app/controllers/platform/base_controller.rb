# frozen_string_literal: true

module Platform
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_platform_admin

    private

    def require_platform_admin
      return if current_user.super_admin?

      redirect_to root_path, alert: t("platform.unauthorized")
    end
  end
end
