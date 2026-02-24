class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    load_calendar_data if tenant_staff?
  end

  private

  def load_calendar_data
    return unless current_tenant

    space = current_tenant
    today_start = Time.current.beginning_of_day
    today_end = Time.current.end_of_day
    week_start = Time.current.beginning_of_week
    week_end = Time.current.end_of_week
    month_start = Time.current.beginning_of_month
    month_end = Time.current.end_of_month

    base_scope = space.appointments.includes(:client).where.not(status: :cancelled)

    @calendar_today = base_scope.where(scheduled_at: today_start..today_end).order(:scheduled_at)
    @calendar_week = base_scope.where(scheduled_at: week_start..week_end).order(:scheduled_at)
    @calendar_month = base_scope.where(scheduled_at: month_start..month_end).order(:scheduled_at)

    @stats_today = calendar_stats(space, @calendar_today, today_start, today_end)
    @stats_week = calendar_stats(space, @calendar_week, week_start, week_end)
    @stats_month = calendar_stats(space, @calendar_month, month_start, month_end)
  end

  def calendar_stats(space, appointments, from, to)
    {
      total: appointments.size,
      empty_slots: space.empty_slots_count(from_date: from, to_date: to),
      pending: appointments.pending.size,
      confirmed: appointments.confirmed.size
    }
  end
end
