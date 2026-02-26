# frozen_string_literal: true

module Platform
  class SpaceAppointmentsController < Platform::BaseController
    include FilterableByDateRange
    include Platform::SpaceScoped

    before_action :set_appointment, only: [ :show ]

    def index
      base = @space.appointments.includes(:customer, :space)
      base = apply_status_filter(base)
      base = apply_date_range_filter(base, timezone: @space)
      @appointments = base.order(scheduled_at: :desc, created_at: :desc).page(params[:page]).per(20)
    end

    def show
    end

    private

    def set_appointment
      @appointment = @space.appointments.find(params[:id])
    end

    def apply_status_filter(scope)
      return scope unless Appointment.statuses.key?(params[:status].to_s)

      scope.where(status: params[:status])
    end
  end
end
