class LandingController < ApplicationController
  layout "landing"

  def index
    if user_signed_in?
      redirect_to dashboard_path
      return
    end

    @plans = Billing::Plan.visible.ordered
  end
end
