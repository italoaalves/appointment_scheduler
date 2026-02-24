# frozen_string_literal: true

class AppointmentCreator
  def self.call(space:, client: nil, attributes:)
    appointment = nil
    Time.use_zone(TimezoneResolver.zone(space)) do
      attrs = attributes.to_h.with_indifferent_access
      attrs[:client] = client if client.present?
      appointment = space.appointments.build(attrs)
      appointment.status ||= :pending
      appointment.requested_at ||= Time.current if appointment.pending?
    end
    appointment
  end
end
