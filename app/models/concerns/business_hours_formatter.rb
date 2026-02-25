# frozen_string_literal: true

module BusinessHoursFormatter
  extend self

  # Formats availability windows into a human-readable string.
  # windows: array of objects/hashes with weekday (0-6), opens_at, closes_at
  def format(windows, locale: I18n.locale)
    return nil if windows.blank?

    valid = windows.select { |w| (w.opens_at.present? && w.closes_at.present?) }
    return nil if valid.empty?

    I18n.with_locale(locale) do
      abbr = I18n.t("date.abbr_day_names")
      every_day = I18n.t("space.settings.edit.availability_preset_every_day")

      groups = valid.group_by { |w| [ time_key(w.opens_at), time_key(w.closes_at) ] }

      groups.map do |_key, group_windows|
        days = group_windows.map { |w| extract_weekday(w) }.compact.sort
        day_str = format_weekday_range(days, abbr: abbr, every_day: every_day)
        open_str = format_time(extract_opens_at(group_windows.first))
        close_str = format_time(extract_closes_at(group_windows.first))
        "#{day_str} #{open_str}–#{close_str}"
      end.join(", ")
    end
  end

  private

  def extract_weekday(w)
    w.respond_to?(:weekday) ? w.weekday : w[:weekday]
  end

  def extract_opens_at(w)
    w.respond_to?(:opens_at) ? w.opens_at : w[:opens_at]
  end

  def extract_closes_at(w)
    w.respond_to?(:closes_at) ? w.closes_at : w[:closes_at]
  end

  def time_key(t)
    normalize_time(t)
  end

  def format_time(t)
    return "" if t.blank?

    normalize_time(t)
  end

  def normalize_time(t)
    return "" if t.blank?

    if t.respond_to?(:strftime)
      t.strftime("%H:%M")
    else
      str = t.is_a?(String) ? t : t.to_s
      str[/\d{1,2}:\d{2}\b/] || str
    end
  end

  def format_weekday_range(weekdays, abbr:, every_day:)
    case weekdays
    when [ 1, 2, 3, 4, 5 ] then "#{abbr[1]}–#{abbr[5]}"
    when [ 1, 2, 3, 4, 5, 6 ] then "#{abbr[1]}–#{abbr[6]}"
    when [ 0, 1, 2, 3, 4, 5, 6 ] then every_day
    else weekdays.map { |w| abbr[w] }.join(", ")
    end
  end
end
