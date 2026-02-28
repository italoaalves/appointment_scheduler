module ApplicationHelper
  def unread_notifications_count
    return 0 unless user_signed_in?

    @_unread_notifications_count ||= current_user.notifications.unread.count
  end

  def timezone_for(space_or_timezone)
    TimezoneResolver.zone(space_or_timezone)
  end

  def format_appointment_time(datetime, space: nil, format: :default)
    return nil if datetime.blank?

    tz = TimezoneResolver.zone(space)
    local = datetime.in_time_zone(tz)
    case format
    when :long then local.strftime("%B %d, %Y at %l:%M %p")
    when :short then local.strftime("%b %d, %Y %l:%M %p")
    when :date_only then local.strftime("%B %d, %Y")
    when :short_date then local.strftime("%b %d, %Y")
    else local.strftime("%b %d, %Y %l:%M %p")
    end
  end

  def format_datetime_in_zone(datetime, timezone, format_string = "%b %d, %Y %l:%M %p")
    return nil if datetime.blank?

    tz = TimezoneResolver.zone(timezone)
    datetime.in_time_zone(tz).strftime(format_string)
  end

  COMMON_TIMEZONES = [
    "UTC",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "America/Sao_Paulo",
    "America/Buenos_Aires",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Europe/Madrid",
    "Europe/Rome",
    "Europe/Amsterdam",
    "Asia/Tokyo",
    "Asia/Shanghai",
    "Asia/Singapore",
    "Asia/Dubai",
    "Australia/Sydney",
    "Australia/Melbourne",
    "Pacific/Auckland"
  ].freeze

  OTHER_TIMEZONE_VALUE = "__other__".freeze

  def common_timezone_options_for_select(current_value = nil)
    zones = COMMON_TIMEZONES.dup
    zones.unshift(current_value) if current_value.present? && !COMMON_TIMEZONES.include?(current_value)
    options = zones.map { |tz| [ "#{tz} (UTC #{Time.find_zone(tz)&.formatted_offset || ''})", tz ] }
    options << [ I18n.t("space.settings.edit.timezone_other"), OTHER_TIMEZONE_VALUE ]
    options.unshift([ I18n.t("space.settings.edit.timezone_prompt"), "" ])
  end
end
