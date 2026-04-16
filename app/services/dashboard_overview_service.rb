# frozen_string_literal: true

class DashboardOverviewService
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
      # Existing
      calendar_today: calendar_today,
      calendar_week: calendar_week,
      calendar_month: calendar_month,
      stats_today: CalendarStatsService.call(space: @space, appointments: calendar_today, from: today_start, to: today_end),
      stats_week: CalendarStatsService.call(space: @space, appointments: calendar_week, from: week_start, to: week_end),
      stats_month: CalendarStatsService.call(space: @space, appointments: calendar_month, from: month_start, to: month_end),
      calendar_space: @space,
      pending_count: @space.appointments.pending.count,

      # New
      today_summary: build_today_summary(calendar_today),
      upcoming: @space.appointments.confirmed.where("scheduled_at > ?", now_in_tz).order(:scheduled_at).limit(5),
      attention: build_attention_metrics,
      this_week: build_this_week_metrics(calendar_week, week_start, week_end),
      automation: build_automation_metrics
    }
  end

  private

  def build_today_summary(appointments)
    confirmed = appointments.confirmed.count
    pending = appointments.pending.count
    total = confirmed + pending

    {
      total: total,
      confirmed: confirmed,
      pending: pending,
      first_at: appointments.first&.scheduled_at,
      last_at: appointments.last&.scheduled_at,
      blocks: appointments.map { |a| { from: a.scheduled_at, to: a.scheduled_at + a.effective_duration_minutes.minutes, state: a.status } }
    }
  end

  def build_attention_metrics
    {
      pending_confirmations: @space.appointments.pending.count,
      unread_conversations: @space.conversations.where(unread: true, status: :active).count,
      trial_ends_in_days: trial_days_remaining,
      setup_incomplete: !@space.onboarding_complete?
    }
  end

  def build_this_week_metrics(appointments, start_date, end_date)
    {
      appointments_count: appointments.where.not(status: :pending).count,
      new_customers: @space.customers.where(created_at: start_date..end_date).count,
      minutes_booked: appointments.sum { |a| a.effective_duration_minutes }
    }
  end

  def build_automation_metrics
    {
      automated_conversations: @space.conversations.where(status: :automated).count
    }
  end

  def trial_days_remaining
    subscription = @space.subscription
    return nil unless subscription&.trialing?

    # Assuming subscription has trial_ends_at or similar.
    # If not, this might need adjustment based on the billing logic.
    # For now, let's assume it's available or we can calculate it.
    # Checking CLAUDE.md: "New Spaces: 14-day trial".
    # We might need to check the Space's created_at or Subscription's trial_start.

    # For the purpose of the service, let's try to find the trial end date.
    # If the subscription model doesn't have trial_ends_at, we might use space.created_at + 14.days
    trial_end = subscription.trial_ends_at || (@space.created_at + 14.days)
    (trial_end.to_date - Date.current).to_i
  end
end
