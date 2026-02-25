class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.super_admin?
      redirect_to platform_root_path
    elsif tenant_staff?
      load_calendar_data
      render :tenant_dashboard
    else
      render :customer_landing
    end
  end

  private

  def load_calendar_data
    return unless current_tenant

    data = DashboardDataService.call(space: current_tenant)
    data.each { |key, value| instance_variable_set("@#{key}", value) }
  end
end
