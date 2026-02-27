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

  def dismiss_welcome
    pref = current_user.user_preference || current_user.create_user_preference!(locale: I18n.default_locale.to_s)
    pref.update!(dismissed_welcome_card: true)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("dashboard_welcome_card") }
      format.html { redirect_to root_path }
    end
  end

  private

  def stop_impersonation_and_redirect
    session.delete(:impersonated_user_id)
    redirect_to platform_users_path, notice: t("platform.impersonation.stopped")
  end

  def load_calendar_data
    return unless current_tenant

    data = DashboardDataService.call(space: current_tenant)
    @calendar_today = data[:calendar_today]
    @calendar_week = data[:calendar_week]
    @calendar_month = data[:calendar_month]
    @stats_today = data[:stats_today]
    @stats_week = data[:stats_week]
    @stats_month = data[:stats_month]
    @calendar_space = data[:calendar_space]
    @pending_count = data[:pending_count]
  end
end
