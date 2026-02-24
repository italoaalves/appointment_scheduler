# frozen_string_literal: true

class BackfillAvailabilityFromBusinessHours < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:availability_schedules)

    Space.find_each do |space|
      schedule = space.business_hours_schedule.presence
      next if schedule.blank? || !schedule.is_a?(Hash) || schedule.empty?

      avail = space.availability_schedule || space.build_availability_schedule
      avail.timezone = space.timezone
      avail.save!

      schedule.each do |wday_str, hours|
        next unless hours.is_a?(Hash)
        open_str = hours["open"].to_s.strip
        close_str = hours["close"].to_s.strip
        next if open_str.blank? || close_str.blank?

        weekday = wday_str.to_i
        next unless weekday.between?(0, 6)

        next unless open_str.match?(/\A\d{1,2}:\d{2}\z/) && close_str.match?(/\A\d{1,2}:\d{2}\z/)

        w = avail.availability_windows.find_or_initialize_by(weekday: weekday)
        w.opens_at = Time.zone.parse("2000-01-01 #{open_str}")
        w.closes_at = Time.zone.parse("2000-01-01 #{close_str}")
        w.save!
      end
    end
  end

  def down
    # No-op: we don't remove availability_schedules on rollback
  end
end
