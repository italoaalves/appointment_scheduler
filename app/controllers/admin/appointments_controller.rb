# frozen_string_literal: true

module Admin
  class AppointmentsController < Admin::BaseController
    before_action :set_appointment, only: [ :show, :edit, :update, :destroy, :approve, :deny, :cancel ]

    def index
      @appointments = current_tenant.appointments.includes(:client).order(scheduled_at: :desc, created_at: :desc)
    end

    def show
    end

    def new
      @appointment = current_tenant.appointments.build
    end

    def create
      @appointment = current_tenant.appointments.build(appointment_params)
      @appointment.requested_at ||= Time.current if @appointment.requested?

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

    def approve
      @appointment.update(status: :confirmed)
      redirect_to admin_appointments_path, notice: t("admin.appointments.approve.notice")
    end

    def deny
      @appointment.update(status: :denied)
      redirect_to admin_appointments_path, notice: t("admin.appointments.deny.notice")
    end

    def cancel
      @appointment.update(status: :cancelled)
      redirect_to admin_appointments_path, notice: t("admin.appointments.cancel.notice")
    end

    private

    def set_appointment
      @appointment = current_tenant.appointments.find(params[:id])
    end

    def appointment_params
      params.require(:appointment).permit(:client_id, :scheduled_at, :status)
    end
  end
end
