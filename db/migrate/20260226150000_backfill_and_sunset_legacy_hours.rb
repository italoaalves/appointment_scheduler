# frozen_string_literal: true

# Ensures every Space has an AvailabilitySchedule before the legacy
# business_hours_schedule JSONB fallback is removed from Schedulable.
#
# Spaces already migrated by 20260225150001 are skipped (availability_schedule
# already present). Spaces with non-empty JSONB but no schedule are also
# handled (defensive re-run). Spaces with empty/nil JSONB are seeded with
# the DEFAULT_BUSINESS_HOURS constant (Mon–Fri 09:00–17:00).
class BackfillAndSunsetLegacyHours < ActiveRecord::Migration[8.0]
  DEFAULT_HOURS = {
    "1" => { "open" => "09:00", "close" => "17:00" },
    "2" => { "open" => "09:00", "close" => "17:00" },
    "3" => { "open" => "09:00", "close" => "17:00" },
    "4" => { "open" => "09:00", "close" => "17:00" },
    "5" => { "open" => "09:00", "close" => "17:00" }
  }.freeze

  def up
    return unless table_exists?(:availability_schedules)

    Space.find_each do |space|
      next if AvailabilitySchedule.exists?(schedulable: space)

      schedule_data = space.business_hours_schedule.presence
      schedule_data = DEFAULT_HOURS if schedule_data.blank? || !schedule_data.is_a?(Hash) || schedule_data.empty?

      avail = AvailabilitySchedule.create!(
        schedulable: space,
        timezone: space.timezone.presence || "UTC"
      )

      schedule_data.each do |wday_str, hours|
        next unless hours.is_a?(Hash)

        open_str  = hours["open"].to_s.strip
        close_str = hours["close"].to_s.strip
        next if open_str.blank? || close_str.blank?
        next unless open_str.match?(/\A\d{1,2}:\d{2}\z/) && close_str.match?(/\A\d{1,2}:\d{2}\z/)

        weekday = wday_str.to_i
        next unless weekday.between?(0, 6)

        avail.availability_windows.create!(
          weekday:   weekday,
          opens_at:  Time.utc(2000, 1, 1, *open_str.split(":").map(&:to_i)),
          closes_at: Time.utc(2000, 1, 1, *close_str.split(":").map(&:to_i))
        )
      end
    end
  end

  def down
    # No-op: removing availability rows on rollback would lose data
  end
end
