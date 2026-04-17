# frozen_string_literal: true

module Scheduling
  module Commands
    class ConfirmAppointment < Base
      private

      def event_type
        "appointment.confirmed"
      end

      def guard(appointment)
        return Result.err(error: :already_finished, appointment: appointment) if appointment.finished?
        return Result.err(error: :cancelled, appointment: appointment) if appointment.cancelled?
        return Result.err(error: :in_past, appointment: appointment) if appointment.scheduled_in_past?

        nil
      end

      def mutate!(appointment)
        appointment.update!(
          status: :confirmed,
          confirmation_state: :confirmed_by_customer,
          confirmation_decided_at: Time.current,
          confirmation_decided_via: @metadata[:via] || @metadata["via"] || "command"
        )
      end
    end
  end
end
