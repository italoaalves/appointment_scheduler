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
                                   .order(requested_at: :desc, created_at: :desc)
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
      @appointment.update(status: :confirmed)
      redirect_to admin_appointments_path, notice: t("admin.appointments.confirm.notice")
    end

    def cancel
      @appointment.update(status: :cancelled)
      redirect_to admin_appointments_path, notice: t("admin.appointments.cancel.notice")
    end

    def no_show
      unless @appointment.scheduled_in_past?
        redirect_to admin_appointment_path(@appointment), alert: t("admin.appointments.no_show.cannot_before_scheduled")
        return
      end
      @appointment.update(status: :no_show)
      redirect_back fallback_location: admin_appointments_path, notice: t("admin.appointments.no_show.notice")
    end

    def finish_form
      unless @appointment.scheduled_in_past?
        redirect_to admin_appointment_path(@appointment), alert: t("admin.appointments.finish.cannot_before_scheduled")
        return
      end
    end

    def finish
      unless @appointment.scheduled_in_past?
        redirect_to admin_appointment_path(@appointment), alert: t("admin.appointments.finish.cannot_before_scheduled")
        return
      end
      finished_at = parse_finished_at
      @appointment.update(status: :finished, finished_at: finished_at)
      redirect_to admin_appointment_path(@appointment), notice: t("admin.appointments.finish.notice")
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

    def parse_finished_at
      return Time.current if params[:finished_at].blank?

      tz = TimezoneResolver.zone(@appointment.space)
      tz.parse(params[:finished_at].to_s)
    rescue ArgumentError
      Time.current
    end
  end
end
