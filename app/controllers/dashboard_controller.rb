class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    load_calendar_data if tenant_staff?
  end

  private

  def load_calendar_data
    return unless current_tenant

    space = current_tenant
    tz = TimezoneResolver.zone(space)
    now_in_tz = Time.current.in_time_zone(tz)

    today_start = now_in_tz.beginning_of_day
    today_end = now_in_tz.end_of_day
    week_start = now_in_tz.beginning_of_week
    week_end = now_in_tz.end_of_week
    month_start = now_in_tz.beginning_of_month
    month_end = now_in_tz.end_of_month

    base_scope = space.appointments.includes(:customer, :space).where.not(status: :cancelled)

    @calendar_today = base_scope.where(scheduled_at: today_start..today_end).order(:scheduled_at)
    @calendar_week = base_scope.where(scheduled_at: week_start..week_end).order(:scheduled_at)
    @calendar_month = base_scope.where(scheduled_at: month_start..month_end).order(:scheduled_at)

    @stats_today = CalendarStatsService.call(space: space, appointments: @calendar_today, from: today_start, to: today_end)
    @stats_week = CalendarStatsService.call(space: space, appointments: @calendar_week, from: week_start, to: week_end)
    @stats_month = CalendarStatsService.call(space: space, appointments: @calendar_month, from: month_start, to: month_end)
    @calendar_space = space
  end
end
