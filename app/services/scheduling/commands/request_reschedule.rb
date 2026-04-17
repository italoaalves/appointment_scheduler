# frozen_string_literal: true

module Scheduling
  module Commands
    class RequestReschedule < Base
      private

      def event_type
        "appointment.reschedule_requested"
      end

      def guard(appointment)
        return Result.err(error: :already_finished, appointment: appointment) if appointment.finished?
        return Result.err(error: :already_cancelled, appointment: appointment) if appointment.cancelled?

        nil
      end

      def mutate!(appointment)
        appointment.update!(
          confirmation_state: :rescheduled_by_customer,
          confirmation_decided_at: Time.current,
          confirmation_decided_via: @metadata[:via] || @metadata["via"] || "command"
        )

        Inbox::EscalationService.call(appointment: appointment, reason: :reschedule_requested)
      end
    end
  end
end
