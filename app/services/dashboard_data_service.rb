# frozen_string_literal: true

class DashboardDataService
  def self.call(space:)
    new(space: space).call
  end

  def initialize(space:)
    @space = space
  end

  def call
    tz = TimezoneResolver.zone(@space)
    now_in_tz = Time.current.in_time_zone(tz)

    today_start = now_in_tz.beginning_of_day
    today_end = now_in_tz.end_of_day
    week_start = now_in_tz.beginning_of_week
    week_end = now_in_tz.end_of_week
    month_start = now_in_tz.beginning_of_month
    month_end = now_in_tz.end_of_month

    base_scope = @space.appointments.includes(:customer, :space).where.not(status: :cancelled)
    calendar_today = base_scope.where(scheduled_at: today_start..today_end).order(:scheduled_at)
    calendar_week = base_scope.where(scheduled_at: week_start..week_end).order(:scheduled_at)
    calendar_month = base_scope.where(scheduled_at: month_start..month_end).order(:scheduled_at)

    {
      calendar_today: calendar_today,
      calendar_week: calendar_week,
      calendar_month: calendar_month,
      stats_today: CalendarStatsService.call(space: @space, appointments: calendar_today, from: today_start, to: today_end),
      stats_week: CalendarStatsService.call(space: @space, appointments: calendar_week, from: week_start, to: week_end),
      stats_month: CalendarStatsService.call(space: @space, appointments: calendar_month, from: month_start, to: month_end),
      calendar_space: @space,
      pending_count: @space.appointments.pending.count
    }
  end
end
