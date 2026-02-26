class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if impersonating?
      return stop_impersonation_and_redirect unless tenant_staff?
    elsif real_current_user&.super_admin?
      redirect_to platform_root_path
      return
    elsif tenant_staff?
      load_calendar_data
      render :tenant_dashboard
      return
    end

    sign_out real_current_user
    redirect_to new_user_session_path, alert: t("space.unauthorized")
  end

  private

  def stop_impersonation_and_redirect
    session.delete(:impersonated_user_id)
    redirect_to platform_users_path, notice: t("platform.impersonation.stopped")
  end

  def load_calendar_data
    return unless current_tenant

    data = DashboardDataService.call(space: current_tenant)
    data.each { |key, value| instance_variable_set("@#{key}", value) }
  end
end
