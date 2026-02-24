# frozen_string_literal: true

class AvailabilitySchedule < ApplicationRecord
  belongs_to :schedulable, polymorphic: true
  has_many :availability_windows, dependent: :destroy
  has_many :availability_exceptions, dependent: :destroy

  accepts_nested_attributes_for :availability_windows, allow_destroy: true
  accepts_nested_attributes_for :availability_exceptions, allow_destroy: true

  after_save { BusinessHoursCacheService.call(schedule: self) }

  def windows_for_date(date)
    exception = availability_exceptions
      .where("starts_on <= ? AND ends_on >= ?", date, date)
      .order(Arel.sql("kind = #{AvailabilityException.kinds[:closed]} DESC"))
      .first

    case exception&.kind&.to_sym
    when :closed
      []
    when :reduced_hours, :extended_hours
      return [] if exception.opens_at.blank? || exception.closes_at.blank?
      [ { opens_at: exception.opens_at, closes_at: exception.closes_at } ]
    else
      availability_windows
        .where(weekday: date.wday)
        .where.not(opens_at: nil)
        .where.not(closes_at: nil)
        .map { |w| { opens_at: w.opens_at, closes_at: w.closes_at } }
    end
  end
end
