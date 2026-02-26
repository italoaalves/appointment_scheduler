# frozen_string_literal: true

module Spaces
  module Space
    class PoliciesController < Spaces::BaseController
      include RequirePermission

      require_permission :manage_policies, only: [ :edit, :update ]
      before_action :set_space, only: [ :edit, :update ]

      def edit
      end

      def update
        if @space.update(policy_params)
          redirect_to edit_settings_space_policies_path, notice: t("space.policies.update.notice")
        else
          render :edit
        end
      end

      private

      def set_space
        @space = current_tenant
        redirect_to root_path, alert: t("space.settings.no_space") unless @space
      end

      def policy_params
        raw = params.require(:space).permit(
          :cancellation_min_hours_before,
          :reschedule_min_hours_before,
          :request_max_days_ahead,
          :request_min_hours_ahead
        )
        raw.transform_values { |v| v.presence == "" ? nil : v }
      end
    end
  end
end
