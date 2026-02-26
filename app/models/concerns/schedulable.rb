# frozen_string_literal: true

module Schedulable
  extend ActiveSupport::Concern

  included do
    has_one :availability_schedule, as: :schedulable, dependent: :destroy
    accepts_nested_attributes_for :availability_schedule, allow_destroy: true
  end

  def windows_for_date(date)
    if availability_schedule.present?
      availability_schedule.windows_for_date(date)
    else
      legacy_windows_for_date(date)
    end
  end

  def available_slots(from_date:, to_date:, limit: 50)
    Spaces::SlotAvailabilityService.call(schedulable: self, from_date: from_date, to_date: to_date, limit: limit)
  end

  def empty_slots_count(from_date:, to_date:)
    available_slots(from_date: from_date, to_date: to_date, limit: 2000).size
  end

  def effective_timezone
    (availability_schedule&.timezone.presence || try(:timezone)).to_s
  end

  private

  def legacy_windows_for_date(date)
    schedule = legacy_business_schedule[date.wday.to_s]
    return [] if schedule.blank?

    open_hm = parse_legacy_time(schedule["open"])
    close_hm = parse_legacy_time(schedule["close"])
    return [] if open_hm.nil? || close_hm.nil?

    base = Time.utc(2000, 1, 1)
    [
      {
        opens_at: base + open_hm[:hour].hours + open_hm[:min].minutes,
        closes_at: base + close_hm[:hour].hours + close_hm[:min].minutes
      }
    ]
  end

  def parse_legacy_time(str)
    return nil if str.blank?

    m = str.to_s.strip.match(/\A(\d{1,2}):(\d{2})\z/)
    m ? { hour: m[1].to_i, min: m[2].to_i } : nil
  end

  def legacy_business_schedule
    return {} unless respond_to?(:business_hours_schedule)

    schedule = business_hours_schedule.presence
    schedule ||= self.class.const_get(:DEFAULT_BUSINESS_HOURS) if self.class.const_defined?(:DEFAULT_BUSINESS_HOURS)
    schedule.is_a?(Hash) ? schedule : {}
  end
end
