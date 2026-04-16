# frozen_string_literal: true

module DashboardHelper
  # Time-of-day periods for Today tab (ordered chronologically)
  TODAY_PERIODS = %i[morning afternoon evening night].freeze

  def greeting_for(time_of_day, user)
    name = user&.name || "there"
    case time_of_day
    when :morning then t("dashboard.hero.greeting", name: name)
    when :afternoon then t("dashboard.hero.greeting_afternoon", name: name)
    when :evening then t("dashboard.hero.greeting_evening", name: name)
    else t("dashboard.hero.greeting", name: name)
    end
  end

  def relative_time_short(time, space)
    return "—" unless time.present?

    tz = TimezoneResolver.zone(space)
    local_time = time.in_time_zone(tz)
    diff = (local_time - Time.current.in_time_zone(tz)).to_i

    return "now" if diff.abs < 300
    return "just now" if diff.abs < 600

    if diff > 0
      if diff < 3600
        "in #{diff / 60} min"
      else
        "in #{diff / 3600}h#{(diff % 3600) / 60}m"
      end
    else
      "#{ (diff.abs / 60).to_i } min ago"
    end
  end

  def day_shape_blocks(appointments, space)
    return [] unless appointments.respond_to?(:each)

    appointments.map do |a|
      {
        start_pct: (a.scheduled_at.to_i % 86400).to_f / 86400 * 100,
        end_pct: ((a.scheduled_at + a.effective_duration_minutes.minutes).to_i % 86400).to_f / 86400 * 100,
        state: a.status
      }
    end
  end

  def calendar_today_grouped(appointments, space = nil)
    return {} unless appointments.respond_to?(:each)

    tz = space_timezone(space, appointments)
    groups = appointments.group_by { |a| time_of_day_period(a.scheduled_at, tz) }
    TODAY_PERIODS.index_with { |p| groups[p] || [] }
  end

  def calendar_week_grouped(appointments, space = nil)
    return [] unless appointments.respond_to?(:each)

    tz = space_timezone(space, appointments)
    appointments.group_by { |a| a.scheduled_at&.in_time_zone(tz)&.to_date }.reject { |k, _| k.nil? }.sort
  end

  def calendar_month_grouped(appointments, space = nil)
    return [] unless appointments.respond_to?(:each)

    tz = space_timezone(space, appointments)
    appointments.group_by { |a| a.scheduled_at&.in_time_zone(tz)&.to_date }.reject { |k, _| k.nil? }.sort
  end

  def appointment_ongoing?(appointment)
    return false unless appointment.scheduled_at.present?
    return false unless appointment.pending? || appointment.confirmed?

    tz = TimezoneResolver.zone(appointment.space)
    now = Time.current.in_time_zone(tz)
    local_scheduled = appointment.scheduled_at.in_time_zone(tz)
    duration_minutes = appointment.effective_duration_minutes
    end_at = local_scheduled + duration_minutes.minutes

    now >= local_scheduled && now < end_at
  end

  private

  def space_timezone(space, appointments)
    space_or_model = space || appointments.first&.space
    TimezoneResolver.zone(space_or_model || "UTC")
  end

  # Morning: 5am-12pm | Afternoon: 12pm-6pm | Evening: 6pm-9pm | Night: 9pm-5am
  # hour is read in the space's local timezone
  def time_of_day_period(datetime, tz = nil)
    return :morning if datetime.blank?

    local = tz ? datetime.in_time_zone(tz) : datetime
    hour = local.hour
    case hour
    when 5..11 then :morning
    when 12..17 then :afternoon
    when 18..20 then :evening
    else :night
    end
  end
end
