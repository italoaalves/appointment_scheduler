# frozen_string_literal: true

class AvailabilitySchedule < ApplicationRecord
  belongs_to :schedulable, polymorphic: true
  has_many :availability_windows, dependent: :destroy

  accepts_nested_attributes_for :availability_windows, allow_destroy: true

  after_save { BusinessHoursCacheService.call(schedule: self) }
  after_commit :broadcast_booking_slot_updates

  def windows_for_date(date)
    availability_windows
      .where(weekday: date.wday)
      .where.not(opens_at: nil)
      .where.not(closes_at: nil)
      .map { |w| { opens_at: w.opens_at, closes_at: w.closes_at } }
  end

  private

  def broadcast_booking_slot_updates
    Booking::SlotUpdatesBroadcaster.broadcast_for(schedulable)
  end
end
