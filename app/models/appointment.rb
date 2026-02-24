class Appointment < ApplicationRecord
  belongs_to :space
  belongs_to :customer, optional: true

  before_validation :set_duration_from_space, on: :create

  validate :customer_belongs_to_space, if: :customer_id?

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

  def customer_belongs_to_space
    return unless space_id.present? && customer_id.present?

    unless space.customer_ids.include?(customer_id)
      errors.add(:customer_id, :invalid)
    end
  end
end
