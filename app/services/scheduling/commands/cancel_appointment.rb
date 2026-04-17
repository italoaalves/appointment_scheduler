# frozen_string_literal: true

module Scheduling
  module Commands
    class CancelAppointment < Base
      private

      def event_type
        "appointment.cancelled"
      end

      def guard(appointment)
        return Result.err(error: :already_finished, appointment: appointment) if appointment.finished?
        return Result.err(error: :already_cancelled, appointment: appointment) if appointment.cancelled?

        nil
      end

      def mutate!(appointment)
        appointment.update!(
          status: :cancelled,
          confirmation_state: :declined_by_customer,
          confirmation_decided_at: Time.current,
          confirmation_decided_via: @metadata[:via] || @metadata["via"] || "command"
        )
      end
    end
  end
end
