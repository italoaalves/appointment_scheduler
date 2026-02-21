class AppointmentsController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.admin?
      @appointments = Appointment.all
    else
      @appointments = current_user.appointments
    end
  end

  def new
    @appointment = Appointment.new
  end

  def create
    @appointment = current_user.appointments.build(appointment_params)
    @appointment.status = :requested

    if @appointment.save
      redirect_to appointments_path, notice: "Appointment requested successfully."
    else
      render :new
    end
  end

  def show
    @appointment = Appointment.find(params[:id])
  end

  private

  def appointment_params
    params.require(:appointment).permit(:requested_at, :client_notes)
  end
end