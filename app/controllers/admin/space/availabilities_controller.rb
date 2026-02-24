# frozen_string_literal: true

module Admin
  module Space
    class AvailabilitiesController < Admin::BaseController
      before_action :require_manager
      before_action :set_space, only: [ :edit, :update ]

      def edit
        ensure_availability_schedule_for_form
      end

      def update
        if @space.update(availability_params)
          redirect_to edit_admin_space_availability_path, notice: t("admin.availability.update.notice")
        else
          render :edit
        end
      end

      private

      def set_space
        @space = current_tenant
        redirect_to root_path, alert: t("admin.space.no_space") unless @space
      end

      def require_manager
        return if current_user.manager?

        redirect_to root_path, alert: t("admin.users.manager_only")
      end

      def availability_params
        params.require(:space).permit(
          :timezone,
          :slot_duration_minutes,
          availability_schedule_attributes: [
            :id,
            :timezone,
            availability_windows_attributes: [ :id, :weekday, :opens_at, :closes_at, :_destroy ],
            availability_exceptions_attributes: [ :id, :name, :starts_on, :ends_on, :kind, :opens_at, :closes_at, :_destroy ]
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
