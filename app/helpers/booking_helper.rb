# frozen_string_literal: true

module BookingHelper
  def booking_calendar_token(appointment)
    return nil unless appointment
    verifier = Rails.application.message_verifier(:booking_calendar)
    verifier.generate(appointment.id)
  end

  def booking_timezone_name(space)
    return nil if space.blank?

    if space.respond_to?(:effective_timezone)
      space.effective_timezone.presence || space.try(:timezone)
    else
      space.try(:timezone).presence || space.to_s
    end
  end

  def booking_business_type_label(space)
    return if space&.business_type.blank?

    t("onboarding.step1.business_types.#{space.business_type}", default: space.business_type.humanize)
  end

  def booking_duration_label(minutes)
    return nil if minutes.blank?

    t("booking.summary.duration_minutes", count: minutes)
  end

  def booking_availability_label(space)
    return nil if space.blank?

    space.business_hours.presence || begin
      windows = space.availability_schedule&.availability_windows&.where&.not(opens_at: nil, closes_at: nil)&.order(:weekday)
      BusinessHoursFormatter.format(Array(windows))
    end
  end

  def booking_date_input_value(space:, fallback_date:, selected_date: nil, scheduled_at: nil)
    return selected_date if selected_date.present?
    return fallback_date.iso8601 if scheduled_at.blank?

    booking_timezone(space).parse(scheduled_at.to_s)&.to_date&.iso8601 || fallback_date.iso8601
  rescue ArgumentError, TypeError
    fallback_date.iso8601
  end

  def booking_date_label(datetime, space:)
    return t("booking.summary.not_selected") if datetime.blank?

    I18n.l(datetime.in_time_zone(booking_timezone(space)).to_date, format: :long)
  end

  def booking_time_range_label(datetime, duration_minutes:, space:)
    return t("booking.summary.not_selected") if datetime.blank? || duration_minutes.blank?

    local = datetime.in_time_zone(booking_timezone(space))
    "#{local.strftime("%H:%M")} - #{(local + duration_minutes.minutes).strftime("%H:%M")}"
  end

  def booking_hero_chips(space)
    return [] if space.blank?

    [
      (booking_chip(t("booking.business_hours"), space.business_hours) if space.business_hours.present?),
      booking_chip(t("booking.summary.timezone"), booking_timezone_name(space), tone: :accent),
      booking_chip(t("booking.summary.duration"), booking_duration_label(space.slot_duration_minutes), tone: :neutral)
    ].compact
  end

  private

  def booking_timezone(space)
    TimezoneResolver.zone(booking_timezone_name(space))
  end

  def booking_chip(label, value, tone: :neutral)
    {
      label: label,
      value: value,
      tone: tone
    }
  end
end
