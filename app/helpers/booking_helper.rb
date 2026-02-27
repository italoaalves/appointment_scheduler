# frozen_string_literal: true

module BookingHelper
  def booking_calendar_token(appointment)
    return nil unless appointment
    verifier = Rails.application.message_verifier(:booking_calendar)
    verifier.generate(appointment.id)
  end
end
