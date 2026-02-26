# frozen_string_literal: true

module Spaces
  class AppointmentsController < Spaces::BaseController
    include FilterableByDateRange
    include RequirePermission

    require_permission :manage_appointments, except: [ :index, :pending, :show ], redirect_to: :appointments_path
    require_permission :destroy_appointments, only: [ :destroy ], redirect_to: :appointments_path
    before_action :set_appointment, only: [ :show, :edit, :update, :destroy, :confirm, :cancel, :no_show, :finish_form, :finish ]

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
      @appointment = Spaces::AppointmentCreator.call(
        space: current_tenant,
        attributes: appointment_params
      )
      if @appointment.scheduled_at.present? && !Spaces::SpacePolicyChecker.slot_requestable?(space: current_tenant, scheduled_at: @appointment.scheduled_at)
        flash.now[:alert] = t("booking.slot_outside_window")
        return render :new
      end

      if @appointment.save
        redirect_to appointment_path(@appointment), notice: t("space.appointments.create.notice")
      else
        render :new
      end
    end

    def edit
      if @appointment.cancelled?
        redirect_to appointment_path(@appointment), alert: t("space.appointments.cancelled_locked")
      end
    end

    def update
      if @appointment.cancelled?
        return redirect_to appointment_path(@appointment), alert: t("space.appointments.update.cancelled_locked")
      end

      attrs = appointment_params
      old_scheduled_at = @appointment.scheduled_at
      @appointment.assign_attributes(attrs)

      if rescheduling?(old_scheduled_at)
        if @appointment.rescheduled_from.present?
          @appointment.restore_attributes
          return redirect_to edit_appointment_path(@appointment), alert: t("space.appointments.update.already_rescheduled")
        end
        unless Spaces::SpacePolicyChecker.reschedule_allowed?(appointment: @appointment, actor: current_user, from_scheduled_at: old_scheduled_at)
          @appointment.restore_attributes
          return redirect_to edit_appointment_path(@appointment), alert: t("space.appointments.update.policy_blocked")
        end
        @appointment.rescheduled_from = old_scheduled_at if old_scheduled_at.present?
      end

      if Time.use_zone(TimezoneResolver.zone(@appointment.space)) { @appointment.save }
        redirect_to appointments_path, notice: t("space.appointments.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @appointment.update!(discarded_at: Time.current)
      redirect_to appointments_path, notice: t("space.appointments.destroy.notice")
    end

    def confirm
      result = Spaces::AppointmentTransitionService.call(appointment: @appointment, to_status: :confirmed, actor: current_user)
      handle_transition_result(result, notice: t("space.appointments.confirm.notice"), cancelled_locked_key: "space.appointments.cancelled_locked")
    end

    def cancel
      result = Spaces::AppointmentTransitionService.call(
        appointment: @appointment,
        to_status: :cancelled,
        actor: current_user
      )
      handle_transition_result(result,
        notice: t("space.appointments.cancel.notice"),
        policy_blocked_key: "space.appointments.cancel.policy_blocked",
        cancelled_locked_key: "space.appointments.cancelled_locked")
    end

    def no_show
      result = Spaces::AppointmentTransitionService.call(appointment: @appointment, to_status: :no_show)
      handle_transition_result(result,
        notice: t("space.appointments.no_show.notice"),
        cannot_before_key: "space.appointments.no_show.cannot_before_scheduled",
        cancelled_locked_key: "space.appointments.cancelled_locked")
    end

    def finish_form
      unless @appointment.scheduled_in_past?
        redirect_to appointment_path(@appointment), alert: t("space.appointments.finish.cannot_before_scheduled")
      end
    end

    def finish
      result = Spaces::AppointmentTransitionService.call(
        appointment: @appointment,
        to_status: :finished,
        finished_at_raw: params[:finished_at]
      )
      handle_transition_result(result,
        notice: t("space.appointments.finish.notice"),
        success_redirect: appointment_path(@appointment),
        cannot_before_key: "space.appointments.finish.cannot_before_scheduled",
        cancelled_locked_key: "space.appointments.cancelled_locked")
    end

    private

    def set_appointment
      @appointment = current_tenant.appointments.find(params[:id])
    end

    def appointment_params
      params.require(:appointment).permit(:customer_id, :scheduled_at, :status)
    end

    def rescheduling?(old_scheduled_at)
      return false unless @appointment.confirmed? || @appointment.rescheduled?
      return false if @appointment.scheduled_at.blank? || old_scheduled_at.blank?

      @appointment.scheduled_at != old_scheduled_at
    end

    def apply_status_filter(scope)
      return scope unless Appointment.statuses.key?(params[:status].to_s)

      scope.where(status: params[:status])
    end

    def handle_transition_result(result, notice:, success_redirect: nil, cannot_before_key: nil, policy_blocked_key: nil, cancelled_locked_key: nil)
      if result[:success]
        redirect_to success_redirect.presence || appointments_path, notice: notice
      elsif result[:error_key] == :cancelled_locked && cancelled_locked_key.present?
        redirect_to appointment_path(@appointment), alert: t(cancelled_locked_key)
      elsif result[:error_key] == :cannot_before_scheduled
        key = cannot_before_key || "space.appointments.no_show.cannot_before_scheduled"
        redirect_to appointment_path(@appointment), alert: t(key)
      elsif result[:error_key] == :policy_cancellation_blocked && policy_blocked_key.present?
        redirect_to appointment_path(@appointment), alert: t(policy_blocked_key)
      else
        redirect_back fallback_location: appointments_path,
                      alert: result[:errors]&.to_sentence || t("space.unauthorized")
      end
    end
  end
end
