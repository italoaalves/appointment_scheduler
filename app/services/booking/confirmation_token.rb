# frozen_string_literal: true

module Booking
  class ConfirmationToken
    Payload = Data.define(:appointment_id, :space_id, :context_type, :context_value, :jti)

    VERIFIER = Rails.application.message_verifier(:booking_confirmation)

    def self.generate(appointment:, booking_context:)
      VERIFIER.generate({
        appointment_id: appointment.id,
        space_id: appointment.space_id,
        context_type: booking_context.confirmation_context[:type],
        context_value: booking_context.confirmation_context[:value],
        jti: SecureRandom.uuid
      })
    end

    def self.resolve(token:, booking_context:)
      payload = verified_payload(token)
      return nil unless payload
      return nil unless payload.space_id.to_i == booking_context.space.id

      expected_context = booking_context.confirmation_context
      return nil unless payload.context_type == expected_context[:type]
      return nil unless payload.context_value == expected_context[:value]

      booking_context.space.appointments.find_by(id: payload.appointment_id)
    end

    def self.verify!(token)
      payload_for(VERIFIER.verify(token))
    end

    def self.verified_payload(token)
      payload_for(VERIFIER.verified(token))
    end

    def self.payload_for(raw_payload)
      return nil unless raw_payload.is_a?(Hash)

      appointment_id = raw_payload[:appointment_id] || raw_payload["appointment_id"]
      space_id = raw_payload[:space_id] || raw_payload["space_id"]
      context_type = raw_payload[:context_type] || raw_payload["context_type"]
      context_value = raw_payload[:context_value] || raw_payload["context_value"]
      jti = raw_payload[:jti] || raw_payload["jti"]

      return nil unless appointment_id.present? && space_id.present? && context_type.present? && context_value.present? && jti.present?

      Payload.new(
        appointment_id: appointment_id,
        space_id: space_id,
        context_type: context_type,
        context_value: context_value,
        jti: jti
      )
    end
  end
end
