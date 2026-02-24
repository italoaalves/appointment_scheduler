# frozen_string_literal: true

class BusinessHoursCacheService
  def self.call(schedule:)
    new(schedule: schedule).call
  end

  def initialize(schedule:)
    @schedule = schedule
  end

  def call
    return unless @schedule.schedulable_type == "Space"
    return unless @schedule.schedulable.respond_to?(:update_column)

    windows = @schedule.availability_windows.reload
      .where.not(opens_at: nil)
      .where.not(closes_at: nil)
      .order(:weekday)

    formatted = BusinessHoursFormatter.format(windows.to_a)
    formatted = normalize_times(formatted) if formatted.present?
    @schedule.schedulable.update_column(:business_hours, formatted)
  end

  private

  def normalize_times(str)
    str.gsub(/(\d{1,2}:\d{2}):\d{2}(?:\.\d+)?/, '\1')
  end
end
