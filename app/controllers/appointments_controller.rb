class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_tenant_staff_to_admin
  before_action :set_appointment, only: [ :show, :destroy, :cancel ]

  def index
    @appointments = current_user.appointments.order(scheduled_at: :desc)
  end

  def show
  end

  def new
    @client = Client.find_by(user_id: current_user.id)
    if @client.nil?
      redirect_to appointments_path, alert: t("appointments.no_client")
      return
    end
    @appointment = @client.space.appointments.build(client: @client)
  end

  def create
    @client = Client.find_by(user_id: current_user.id)
    if @client.nil?
      redirect_to appointments_path, alert: t("appointments.no_client")
      return
    end
    @appointment = @client.space.appointments.build(appointment_params.merge(client: @client))
    @appointment.status = "requested"
    @appointment.requested_at = Time.current

    if @appointment.save
      redirect_to appointments_path
    else
      render :new
    end
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_path, notice: "Appointment removed."
  end

  def cancel
    @appointment.update(status: :cancelled)
    redirect_to appointments_path, notice: "Appointment cancelled."
  end

  private

  def set_appointment
    @appointment = current_user.appointments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to appointments_path, alert: t("appointments.not_found")
  end

  def redirect_tenant_staff_to_admin
    redirect_to admin_appointments_path if tenant_staff?
  end

  def appointment_params
    params.require(:appointment).permit(:scheduled_at)
  end
end
