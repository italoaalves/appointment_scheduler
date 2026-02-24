# frozen_string_literal: true

class AvailabilityException < ApplicationRecord
  belongs_to :availability_schedule

  enum :kind, { closed: 0, reduced_hours: 1, extended_hours: 2 }

  validates :starts_on, :ends_on, presence: true
  validate :ends_on_after_starts_on
  validate :hours_required_for_non_closed

  scope :covering_date, ->(date) { where("starts_on <= ? AND ends_on >= ?", date, date) }

  private

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, :must_be_on_or_after_starts_on)
  end

  def hours_required_for_non_closed
    return if closed?
    return if opens_at.present? && closes_at.present?

    errors.add(:base, :opens_and_closes_required) if reduced_hours? || extended_hours?
  end
end
