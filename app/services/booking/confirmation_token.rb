# frozen_string_literal: true

module Booking
  class ConfirmationToken
    VERIFIER = Rails.application.message_verifier(:booking_confirmation)

    def self.generate(appointment:, booking_context:)
      VERIFIER.generate({
        appointment_id: appointment.id,
        space_id: appointment.space_id,
        context_type: booking_context.confirmation_context[:type],
        context_value: booking_context.confirmation_context[:value]
      })
    end

    def self.resolve(token:, booking_context:)
      payload = VERIFIER.verified(token)
      return nil unless payload.is_a?(Hash)

      appointment_id = payload[:appointment_id] || payload["appointment_id"]
      space_id = payload[:space_id] || payload["space_id"]
      context_type = payload[:context_type] || payload["context_type"]
      context_value = payload[:context_value] || payload["context_value"]

      return nil unless appointment_id.present? && space_id.present?
      return nil unless space_id.to_i == booking_context.space.id

      expected_context = booking_context.confirmation_context
      return nil unless context_type == expected_context[:type]
      return nil unless context_value == expected_context[:value]

      booking_context.space.appointments.find_by(id: appointment_id)
    end
  end
end
