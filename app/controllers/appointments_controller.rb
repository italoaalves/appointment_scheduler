class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: [ :show, :destroy, :cancel ]

  def index
    @appointments = current_user.appointments
  end

  def show
  end

  def new
    @appointment = current_user.appointments.new
  end

  def create
    @appointment = current_user.appointments.new(appointment_params)
    @appointment.status = "requested"
    @appointment.requested_at = Time.now

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
  end

  def appointment_params
    params.require(:appointment).permit(:scheduled_at)
  end
end
