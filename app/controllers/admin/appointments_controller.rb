class Admin::AppointmentsController < ApplicationController
  before_action :require_admin
  before_action :set_appointment, only: [ :show, :edit, :update, :destroy, :approve, :deny, :cancel ]

  def index
    @appointments = Appointment.all
  end

  def show
  end

  def new
    @appointment = Appointment.new
  end

  def create
    @appointment = Appointment.new(appointment_params)
    @appointment.requested_at ||= Time.current if @appointment.requested?

    if @appointment.save
      redirect_to admin_appointment_path(@appointment), notice: "Appointment created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @appointment.update(appointment_params)
      redirect_to admin_appointments_path
    else
      render :edit
    end
  end

  def destroy
    @appointment.destroy
    redirect_to admin_appointments_path
  end

  def approve
    @appointment.update(status: :confirmed)
    redirect_to admin_appointments_path, notice: "Appointment confirmed."
  end

  def deny
    @appointment.update(status: :denied)
    redirect_to admin_appointments_path, notice: "Appointment denied."
  end

  def cancel
    @appointment.update(status: :cancelled)
    redirect_to admin_appointments_path, notice: "Appointment cancelled."
  end

  private

  def set_appointment
    @appointment = Appointment.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(:user_id, :scheduled_at, :status)
  end

  def require_admin
    redirect_to root_path unless current_user.admin?
  end
end
