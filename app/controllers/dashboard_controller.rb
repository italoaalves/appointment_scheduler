class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.admin?
      redirect_to admin_appointments_path
    else
      redirect_to appointments_path
    end
  end
end