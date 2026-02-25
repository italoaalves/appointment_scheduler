# frozen_string_literal: true

module Space
  module Space
    class AvailabilitiesController < ::Space::BaseController
      include RequirePermission

      require_permission :manage_space, only: [ :edit, :update ]
      before_action :set_space, only: [ :edit, :update ]

      def edit
        ensure_availability_schedule_for_form
      end

      def update
        if @space.update(availability_params)
          redirect_to edit_settings_space_availability_path, notice: t("space.availability.update.notice")
        else
          render :edit
        end
      end

      private

      def set_space
        @space = current_tenant
        redirect_to root_path, alert: t("space.settings.no_space") unless @space
      end

      def availability_params
        params.require(:space).permit(
          :timezone,
          :slot_duration_minutes,
          availability_schedule_attributes: [
            :id,
            :timezone,
            availability_windows_attributes: [ :id, :weekday, :opens_at, :closes_at, :_destroy ]
          ]
        )
      end

      def ensure_availability_schedule_for_form
        @space.build_availability_schedule if @space.availability_schedule.blank?
        schedule = @space.availability_schedule
        return unless schedule

        (0..6).each do |wday|
          schedule.availability_windows.find_or_initialize_by(weekday: wday)
        end
      end
    end
  end
end
