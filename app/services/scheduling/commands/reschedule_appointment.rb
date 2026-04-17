# frozen_string_literal: true

module Scheduling
  module Commands
    class RescheduleAppointment < Base
      def initialize(new_scheduled_at:, **base_kwargs)
        super(**base_kwargs)
        @new_scheduled_at = new_scheduled_at
      end

      def call
        super
      rescue ActiveRecord::RecordInvalid => e
        raise unless slot_taken_error?(e)

        Result.err(
          error: :slot_taken,
          appointment: @space.appointments.find_by(id: @appointment_id)
        )
      end

      private

      def event_type
        "appointment.rescheduled"
      end

      def guard(appointment)
        return Result.err(error: :already_finished, appointment: appointment) if appointment.finished?
        return Result.err(error: :already_cancelled, appointment: appointment) if appointment.cancelled?
        return Result.err(error: :invalid_time, appointment: appointment) if @new_scheduled_at <= Time.current

        nil
      end

      def mutate!(appointment)
        new_appointment = appointment.space.appointments.create!(
          customer_id: appointment.customer_id,
          scheduled_at: @new_scheduled_at,
          duration_minutes: appointment.duration_minutes,
          status: :pending,
          confirmation_state: :not_applicable,
          rescheduled_from: appointment.scheduled_at
        )

        appointment.update!(status: :rescheduled)
        @metadata = @metadata.merge(new_appointment_id: new_appointment.id)
      end

      def slot_taken_error?(error)
        error.record.is_a?(Appointment) &&
          error.record.errors.of_kind?(:base, :slot_already_booked)
      end
    end
  end
end
