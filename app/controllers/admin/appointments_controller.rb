# frozen_string_literal: true

module Admin
  class AppointmentsController < Admin::BaseController
    before_action :set_appointment, only: [ :show, :edit, :update, :destroy, :confirm, :cancel ]
    before_action :require_manager, only: [ :destroy ]

    def index
      base = current_tenant.appointments.includes(:client)
      base = apply_status_filter(base)
      base = apply_date_range_filter(base)
      @appointments = base.order(scheduled_at: :desc, created_at: :desc).page(params[:page]).per(20)
    end

    def show
    end

    def new
      @appointment = current_tenant.appointments.build
    end

    def create
      @appointment = current_tenant.appointments.build(appointment_params)
      @appointment.requested_at ||= Time.current if @appointment.pending?

      if @appointment.save
        redirect_to admin_appointment_path(@appointment), notice: t("admin.appointments.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @appointment.update(appointment_params)
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

    private

    def set_appointment
      @appointment = current_tenant.appointments.find(params[:id])
    end

    def require_manager
      return if current_user.manager?

      redirect_to admin_appointments_path, alert: t("admin.unauthorized")
    end

    def appointment_params
      params.require(:appointment).permit(:client_id, :scheduled_at, :status)
    end

    def apply_status_filter(scope)
      return scope unless Appointment.statuses.key?(params[:status].to_s)

      scope.where(status: params[:status])
    end

    def apply_date_range_filter(scope)
      from = parse_date(params[:date_from])
      to = parse_date(params[:date_to])
      scope = scope.where(scheduled_at: from.beginning_of_day..) if from
      scope = scope.where(scheduled_at: ..to.end_of_day) if to
      scope
    end

    def parse_date(str)
      return nil if str.blank?

      Date.parse(str.to_s)
    rescue ArgumentError
      nil
    end
  end
end
