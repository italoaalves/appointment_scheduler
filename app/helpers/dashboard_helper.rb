# frozen_string_literal: true

module DashboardHelper
  # Time-of-day periods for Today tab (ordered chronologically)
  TODAY_PERIODS = %i[morning afternoon evening night].freeze

  def calendar_today_grouped(appointments)
    return {} unless appointments.respond_to?(:each)

    groups = appointments.group_by { |a| time_of_day_period(a.scheduled_at) }
    TODAY_PERIODS.index_with { |p| groups[p] || [] }
  end

  def calendar_week_grouped(appointments)
    return [] unless appointments.respond_to?(:each)

    appointments.group_by { |a| a.scheduled_at&.to_date }.reject { |k, _| k.nil? }.sort
  end

  def calendar_month_grouped(appointments)
    return [] unless appointments.respond_to?(:each)

    appointments.group_by { |a| a.scheduled_at&.to_date }.reject { |k, _| k.nil? }.sort
  end

  def appointment_ongoing?(appointment)
    return false unless appointment.scheduled_at.present?
    return false unless appointment.pending? || appointment.confirmed?

    now = Time.current
    duration_minutes = appointment.space&.slot_duration_minutes || 30
    end_at = appointment.scheduled_at + duration_minutes.minutes

    now >= appointment.scheduled_at && now < end_at
  end

  private

  # Morning: 5am-12pm | Afternoon: 12pm-6pm | Evening: 6pm-9pm | Night: 9pm-5am
  def time_of_day_period(datetime)
    return :morning if datetime.blank?

    hour = datetime.hour
    case hour
    when 5..11 then :morning
    when 12..17 then :afternoon
    when 18..20 then :evening
    else :night
    end
  end
end
