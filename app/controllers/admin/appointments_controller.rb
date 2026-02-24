# frozen_string_literal: true

module Admin
  class AppointmentsController < Admin::BaseController
    include FilterableByDateRange

    before_action :set_appointment, only: [ :show, :edit, :update, :destroy, :confirm, :cancel, :no_show, :finish_form, :finish ]
    before_action :require_manager, only: [ :destroy ]

    def index
      base = current_tenant.appointments.includes(:customer, :space)
      base = apply_status_filter(base)
      base = apply_date_range_filter(base, timezone: current_tenant)
      @appointments = base.order(scheduled_at: :desc, created_at: :desc).page(params[:page]).per(20)
    end

    def pending
      @appointments = current_tenant.appointments
                                   .pending
                                   .includes(:customer, :space)
                                   .order(updated_at: :desc)
                                   .page(params[:page]).per(20)
    end

    def show
    end

    def new
      @appointment = current_tenant.appointments.build
    end

    def create
      @appointment = AppointmentCreator.call(
        space: current_tenant,
        attributes: appointment_params
      )

      if @appointment.save
        redirect_to admin_appointment_path(@appointment), notice: t("admin.appointments.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if Time.use_zone(TimezoneResolver.zone(@appointment.space)) { @appointment.update(appointment_params) }
        redirect_to admin_appointments_path, notice: t("admin.appointments.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @appointment.destroy
      redirect_to admin_appointments_path, notice: t("admin.appointments.destroy.notice")
    end

    def confirm
      result = AppointmentTransitionService.call(appointment: @appointment, to_status: :confirmed)
      handle_transition_result(result, notice: t("admin.appointments.confirm.notice"))
    end

    def cancel
      result = AppointmentTransitionService.call(appointment: @appointment, to_status: :cancelled)
      handle_transition_result(result, notice: t("admin.appointments.cancel.notice"))
    end

    def no_show
      result = AppointmentTransitionService.call(appointment: @appointment, to_status: :no_show)
      handle_transition_result(result,
        notice: t("admin.appointments.no_show.notice"),
        cannot_before_key: "admin.appointments.no_show.cannot_before_scheduled")
    end

    def finish_form
      unless @appointment.scheduled_in_past?
        redirect_to admin_appointment_path(@appointment), alert: t("admin.appointments.finish.cannot_before_scheduled")
      end
    end

    def finish
      result = AppointmentTransitionService.call(
        appointment: @appointment,
        to_status: :finished,
        finished_at_raw: params[:finished_at]
      )
      handle_transition_result(result,
        notice: t("admin.appointments.finish.notice"),
        success_redirect: admin_appointment_path(@appointment),
        cannot_before_key: "admin.appointments.finish.cannot_before_scheduled")
    end

    private

    def set_appointment
      @appointment = current_tenant.appointments.find(params[:id])
    end

    def require_manager
      return if current_user.manager?

      redirect_to admin_appointments_path, alert: t("admin.unauthorized")
    end

    def appointment_params
      params.require(:appointment).permit(:customer_id, :scheduled_at, :status)
    end

    def apply_status_filter(scope)
      return scope unless Appointment.statuses.key?(params[:status].to_s)

      scope.where(status: params[:status])
    end

    def handle_transition_result(result, notice:, success_redirect: nil, cannot_before_key: nil)
      if result[:success]
        redirect_to success_redirect.presence || admin_appointments_path, notice: notice
      elsif result[:error_key] == :cannot_before_scheduled
        key = cannot_before_key || "admin.appointments.no_show.cannot_before_scheduled"
        redirect_to admin_appointment_path(@appointment), alert: t(key)
      else
        redirect_back fallback_location: admin_appointments_path,
                      alert: result[:errors]&.to_sentence || t("admin.unauthorized")
      end
    end
  end
end
