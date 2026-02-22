class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Renders dashboard with role-based quick links
  end
end
