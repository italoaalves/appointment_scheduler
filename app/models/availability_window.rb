# frozen_string_literal: true

class AvailabilityWindow < ApplicationRecord
  belongs_to :availability_schedule

  validates :weekday, presence: true, inclusion: { in: 0..6 }
  validates :opens_at, presence: true, unless: :marked_for_destruction?
  validates :closes_at, presence: true, unless: :marked_for_destruction?
  validate :closes_after_opens

  before_validation :mark_for_destruction_if_both_blank

  private

  def mark_for_destruction_if_both_blank
    mark_for_destruction if opens_at.blank? && closes_at.blank?
  end

  def closes_after_opens
    return if opens_at.blank? || closes_at.blank?
    return if closes_at > opens_at

    errors.add(:closes_at, :must_be_after_opens_at)
  end
end
