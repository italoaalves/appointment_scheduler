# frozen_string_literal: true

class SlotAvailabilityService
  def self.call(space:, from_date:, to_date:, limit: 50)
    new(space: space, from_date: from_date, to_date: to_date, limit: limit).call
  end

  def initialize(space:, from_date:, to_date:, limit: 50)
    @space = space
    @from_date = from_date
    @to_date = to_date
    @limit = limit
  end

  def call
    tz = TimezoneResolver.zone(@space)
    slots = []
    duration = @space.slot_duration_minutes.minutes

    @from_date.to_date.upto(@to_date.to_date) do |date|
      break if slots.size >= @limit

      day_schedule = @space.business_schedule[date.wday.to_s]
      next if day_schedule.blank?

      open_time = parse_time(day_schedule["open"])
      close_time = parse_time(day_schedule["close"])
      next if open_time.nil? || close_time.nil?

      slot_start = tz.local(date.year, date.month, date.day, open_time[:hour], open_time[:min])
      slot_end = tz.local(date.year, date.month, date.day, close_time[:hour], close_time[:min])

      while slot_start < slot_end && slots.size < @limit
        slots << slot_start if slot_start > Time.current
        slot_start += duration
      end
    end

    booked_starts = @space.appointments
                          .where(scheduled_at: @from_date..@to_date.end_of_day)
                          .where(status: [ :pending, :confirmed ])
                          .pluck(:scheduled_at)
                          .map do |t|
      st = t.in_time_zone(tz)
      mins = (st.hour * 60 + st.min) / @space.slot_duration_minutes * @space.slot_duration_minutes
      tz.local(st.year, st.month, st.day, mins / 60, mins % 60)
    end.uniq

    slots.reject { |s| booked_starts.include?(s.in_time_zone(tz)) }.first(@limit)
  end

  private

  def parse_time(str)
    return nil if str.blank?

    parts = str.to_s.strip.match(/\A(\d{1,2}):(\d{2})\z/)
    return nil unless parts

    { hour: parts[1].to_i, min: parts[2].to_i }
  end
end
