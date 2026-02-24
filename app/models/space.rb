class Space < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :scheduling_links, dependent: :destroy

  DEFAULT_BUSINESS_HOURS = {
    "1" => { "open" => "09:00", "close" => "17:00" },
    "2" => { "open" => "09:00", "close" => "17:00" },
    "3" => { "open" => "09:00", "close" => "17:00" },
    "4" => { "open" => "09:00", "close" => "17:00" },
    "5" => { "open" => "09:00", "close" => "17:00" }
  }.freeze

  def business_schedule
    return DEFAULT_BUSINESS_HOURS if business_hours_schedule.blank?

    business_hours_schedule
  end

  def available_slots(from_date:, to_date:, limit: 50)
    tz = Time.find_zone(timezone.presence || "UTC")
    slots = []
    duration = slot_duration_minutes.minutes

    from_date.to_date.upto(to_date.to_date) do |date|
      break if slots.size >= limit

      day_schedule = business_schedule[date.wday.to_s]
      next if day_schedule.blank?

      open_time = parse_time(day_schedule["open"])
      close_time = parse_time(day_schedule["close"])
      next if open_time.nil? || close_time.nil?

      slot_start = tz.local(date.year, date.month, date.day, open_time[:hour], open_time[:min])
      slot_end = tz.local(date.year, date.month, date.day, close_time[:hour], close_time[:min])

      while slot_start < slot_end && slots.size < limit
        slots << slot_start if slot_start > Time.current
        slot_start += duration
      end
    end

    booked_starts = appointments.where(scheduled_at: from_date..to_date.end_of_day)
                               .where(status: [ :pending, :confirmed ])
                               .pluck(:scheduled_at)
                               .map do |t|
      st = t.in_time_zone(tz)
      mins = (st.hour * 60 + st.min) / slot_duration_minutes * slot_duration_minutes
      tz.local(st.year, st.month, st.day, mins / 60, mins % 60)
    end.uniq

    slots.reject { |s| booked_starts.include?(s.in_time_zone(tz)) }.first(limit)
  end

  def empty_slots_count(from_date:, to_date:)
    available_slots(from_date: from_date, to_date: to_date, limit: 2000).size
  end

  private

  def parse_time(str)
    return nil if str.blank?

    parts = str.to_s.strip.match(/\A(\d{1,2}):(\d{2})\z/)
    return nil unless parts

    { hour: parts[1].to_i, min: parts[2].to_i }
  end
end

