class Appointment < ApplicationRecord
  belongs_to :space
  belongs_to :client, optional: true

  before_validation :set_duration_from_space, on: :create

  validate :client_belongs_to_space, if: :client_id?

  def effective_duration_minutes
    duration_minutes.presence || space&.slot_duration_minutes || 30
  end

  enum :status, {
    pending: 0,
    confirmed: 1,
    cancelled: 2,
    rescheduled: 3
  }

  private

  def set_duration_from_space
    return if duration_minutes.present?
    return unless space_id.present?

    self.duration_minutes = space.slot_duration_minutes
  end

  def client_belongs_to_space
    return unless space_id.present? && client_id.present?

    unless space.client_ids.include?(client_id)
      errors.add(:client_id, :invalid)
    end
  end
end
