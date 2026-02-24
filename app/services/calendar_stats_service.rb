# frozen_string_literal: true

class CalendarStatsService
  def self.call(space:, appointments:, from:, to:)
    {
      total: appointments.size,
      empty_slots: space.empty_slots_count(from_date: from, to_date: to),
      pending: appointments.pending.size,
      confirmed: appointments.confirmed.size
    }
  end
end
