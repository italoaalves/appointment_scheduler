class Appointment < ApplicationRecord
  belongs_to :space
  belongs_to :customer, optional: true

  before_validation :set_duration_from_space, on: :create

  validate :customer_belongs_to_space, if: :customer_id?
  validate :no_double_booking, if: :requires_slot_validation?

  def effective_duration_minutes
    duration_minutes.presence || space&.slot_duration_minutes || 30
  end

  def scheduled_in_past?
    scheduled_at.present? && scheduled_at <= Time.current
  end

  enum :status, {
    pending: 0,
    confirmed: 1,
    cancelled: 2,
    rescheduled: 3,
    no_show: 4,
    finished: 5
  }

  private

  def set_duration_from_space
    return if duration_minutes.present?
    return unless space_id.present?

    self.duration_minutes = space.slot_duration_minutes
  end

  def customer_belongs_to_space
    return unless space_id.present? && customer_id.present?

    unless space.customers.exists?(id: customer_id)
      errors.add(:customer_id, :invalid)
    end
  end

  def requires_slot_validation?
    (confirmed? || rescheduled?) && scheduled_at.present?
  end

  def no_double_booking
    return unless space_id.present? && scheduled_at.present?

    my_end = scheduled_at + effective_duration_minutes.minutes
    conflict_exists = space.appointments
      .where(status: [ :confirmed, :rescheduled ])
      .where.not(id: id)
      .where.not(scheduled_at: nil)
      .where("scheduled_at < ? AND (scheduled_at + (COALESCE(duration_minutes, ?) || ' minutes')::interval) > ?",
             my_end, space&.slot_duration_minutes || 30, scheduled_at)
      .exists?

    errors.add(:base, :slot_already_booked) if conflict_exists
  end
end
