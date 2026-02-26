# frozen_string_literal: true

module Spaces
  class SlotAvailabilityService
    def self.call(schedulable:, from_date:, to_date:, limit: 50)
      new(schedulable: schedulable, from_date: from_date, to_date: to_date, limit: limit).call
    end

    def initialize(schedulable:, from_date:, to_date:, limit: 50)
      @schedulable = schedulable
      @from_date = from_date
      @to_date = to_date
      @limit = limit
    end

    def call
      tz = TimezoneResolver.zone(@schedulable.effective_timezone.presence || @schedulable)
      slots = []
      duration = @schedulable.slot_duration_minutes.minutes

      @from_date.to_date.upto(@to_date.to_date) do |date|
        break if slots.size >= @limit

        @schedulable.windows_for_date(date).each do |window|
          open_t = window[:opens_at]
          close_t = window[:closes_at]
          slot_start = tz.local(date.year, date.month, date.day, open_t.hour, open_t.min)
          slot_end = tz.local(date.year, date.month, date.day, close_t.hour, close_t.min)

          while slot_start < slot_end && slots.size < @limit
            slots << slot_start if slot_start > Time.current
            slot_start += duration
          end
        end
      end

      booked_starts = schedulable_appointments
        .where(scheduled_at: @from_date..@to_date.end_of_day)
        .where(status: [ :pending, :confirmed, :rescheduled ])
        .pluck(:scheduled_at)
        .map do |t|
          st = t.in_time_zone(tz)
          mins = (st.hour * 60 + st.min) / @schedulable.slot_duration_minutes * @schedulable.slot_duration_minutes
          tz.local(st.year, st.month, st.day, mins / 60, mins % 60)
        end.uniq

      slots.reject { |s| booked_starts.include?(s.in_time_zone(tz)) }.first(@limit)
    end

    private

    def schedulable_appointments
      @schedulable.respond_to?(:appointments) ? @schedulable.appointments : Appointment.none
    end
  end
end
