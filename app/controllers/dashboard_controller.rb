class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.super_admin?
      load_platform_stats
    elsif tenant_staff?
      load_calendar_data
    end
  end

  private

  def load_platform_stats
    @platform_spaces_count = Space.count
    @platform_users_count = User.count
    @platform_appointments_count = Appointment.count
  end

  def load_calendar_data
    return unless current_tenant

    data = DashboardDataService.call(space: current_tenant)
    data.each { |key, value| instance_variable_set("@#{key}", value) }
  end
end
