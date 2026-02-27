# frozen_string_literal: true

module Booking
  class CalendarFileGenerator
    PRODID = "-//AppointmentScheduler//Booking//EN"

    def self.call(appointment:)
      new(appointment: appointment).call
    end

    def initialize(appointment:)
      @appointment = appointment
      @space = appointment.space
    end

    def call
      [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:#{PRODID}",
        "BEGIN:VEVENT",
        "DTSTART:#{format_utc(start_time)}",
        "DTEND:#{format_utc(end_time)}",
        "SUMMARY:#{escape_summary(summary)}",
        ("LOCATION:#{escape_text(@space.address)}" if @space.address.present?),
        "DESCRIPTION:#{escape_text(description)}",
        "STATUS:TENTATIVE",
        "END:VEVENT",
        "END:VCALENDAR"
      ].compact.join("\r\n")
    end

    def filename
      "appointment-#{@appointment.id}.ics"
    end

    private

    def start_time
      @appointment.scheduled_at
    end

    def end_time
      return start_time unless start_time
      start_time + @appointment.effective_duration_minutes.minutes
    end

    def format_utc(time)
      return "" unless time
      time.utc.strftime("%Y%m%dT%H%M%SZ")
    end

    def summary
      I18n.t("booking.calendar.summary", business_name: @space.name)
    end

    def description
      @space.booking_success_message.presence ||
        I18n.t("booking.calendar.default_description")
    end

    def escape_text(str)
      return "" if str.blank?
      str.to_s.gsub(/\\/, "\\\\").gsub(/;/, "\\;").gsub(/,/, "\\,").gsub(/\n/, "\\n")
    end

    def escape_summary(str)
      escape_text(str.to_s.truncate(75))
    end
  end
end
