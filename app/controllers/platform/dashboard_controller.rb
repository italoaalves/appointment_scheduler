# frozen_string_literal: true

module Platform
  class DashboardController < Platform::BaseController
    def index
      @platform_spaces_count = Space.count
      @platform_users_count = User.count
      @platform_appointments_count = Appointment.count
    end
  end
end
