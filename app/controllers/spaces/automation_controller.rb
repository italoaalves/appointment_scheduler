# frozen_string_literal: true

module Spaces
  class AutomationController < BaseController
    include RequirePermission

    LEAD_HOUR_OPTIONS = [ 48, 24, 12, 6, 2, 1 ].freeze

    require_permission :access_space_dashboard, redirect_to: :root_path
    before_action :set_space

    def show
    end

    def update
      if @space.update(automation_params)
        redirect_to settings_automation_path, status: :see_other
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_space
      @space = current_tenant
    end

    def automation_params
      permitted = params.require(:space).permit(
        :appointment_automation_enabled,
        :confirmation_quiet_hours_start,
        :confirmation_quiet_hours_end,
        confirmation_lead_hours: []
      )

      permitted[:confirmation_lead_hours] = Array(permitted[:confirmation_lead_hours]).compact_blank.map(&:to_i)
      permitted
    end
  end
end
