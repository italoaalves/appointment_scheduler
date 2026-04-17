# frozen_string_literal: true

class BookingConfirmationMailer < ApplicationMailer
  def customer_confirmation(appointment:, confirmation_token: nil)
    @appointment = appointment
    @space = appointment.space
    @customer = appointment.customer
    @confirmation_url = confirmation_token.present? ? confirm_booking_url(confirmation: confirmation_token) : nil

    with_mail_locale(recipient: @customer, fallback_space: @space) do
      tz = TimezoneResolver.zone(@space)
      dt = appointment.scheduled_at&.in_time_zone(tz)
      @date_str = dt ? I18n.l(dt.to_date, format: :long) : "—"
      @time_str = dt ? dt.strftime("%H:%M") : "—"
      @duration = appointment.effective_duration_minutes

      ics = Booking::CalendarFileGenerator.call(appointment: appointment)
      filename = Booking::CalendarFileGenerator.new(appointment: appointment).filename
      attachments[filename] = { mime_type: "text/calendar", content: ics }

      mail(
        to: @customer.email,
        subject: subject,
        reply_to: @space.owner&.email.presence
      )
    end
  end

  private

  def subject
    tz = TimezoneResolver.zone(@space)
    dt = @appointment.scheduled_at&.in_time_zone(tz)
    date_part = dt ? I18n.l(dt.to_date, format: :long) : "—"
    I18n.t("booking.confirmation_email.subject", business_name: @space.name, date: date_part)
  end
end
