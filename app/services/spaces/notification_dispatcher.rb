# frozen_string_literal: true

module Spaces
  class NotificationDispatcher
    def self.call(event:, appointment:)
      new(event: event, appointment: appointment).call
    end

    def initialize(event:, appointment:)
      @event       = event.to_sym
      @appointment = appointment
      @space       = appointment.space
    end

    def call
      recipients_for_event.each do |recipient, channels|
        channels.each do |channel|
          dispatch_to(recipient: recipient, channel: channel)
        end
      end
    rescue => e
      Rails.logger.error(
        "[Notifications] dispatcher_error event=#{@event} appointment_id=#{@appointment.id} " \
        "error_class=#{e.class} error=#{e.message}"
      )
    end

    private

    def recipients_for_event
      case @event
      when :appointment_booked
        recipients = []
        recipients << [ owner, [ :email ] ] if owner.present? && owner.email.present?
        recipients << [ @appointment.customer, [ :email ] ] if @appointment.customer&.email.present?
        recipients
      when :appointment_confirmed, :appointment_cancelled, :appointment_rescheduled
        return [] if @appointment.customer.blank?
        [ [ @appointment.customer, channels_for_customer ] ]
      else
        []
      end
    end

    def owner
      @space.owner
    end

    def channels_for_customer
      channels = []
      channels << :email  if @appointment.customer&.email.present?
      channels << :whatsapp if whatsapp_available?
      channels
    end

    def whatsapp_available?
      return false if @appointment.customer&.phone.blank?
      return false unless Billing::PlanEnforcer.can?(@space, :send_whatsapp)

      true
    end

    def dispatch_to(recipient:, channel:)
      return if recipient.blank?

      if @event == :appointment_booked && channel == :email && recipient.is_a?(Customer)
        send_customer_confirmation(recipient)
      else
        send_owner_notification(recipient, channel)
      end
    end

    def send_customer_confirmation(customer)
      BookingConfirmationMailer.customer_confirmation(appointment: @appointment).deliver_now
    rescue => e
      Rails.logger.error(
        "[Notifications] customer_confirmation_failed appointment_id=#{@appointment.id} " \
        "error_class=#{e.class} error=#{e.message}"
      )
    end

    def send_owner_notification(recipient, channel)
      subject = build_subject(channel)
      body    = build_body(channel)

      result = Messaging::DeliveryService.call(
        channel: channel,
        to:     recipient,
        body:   body,
        subject: channel == :email ? subject : nil
      )

      return if result[:success]

      Rails.logger.warn(
        "[Notifications] delivery_failed event=#{@event} channel=#{channel} " \
        "recipient=#{recipient.inspect} error=#{result[:error]}"
      )
    end

    def build_subject(_channel)
      I18n.t("notifications.#{@event}.subject", **template_params)
    end

    def build_body(_channel)
      I18n.t("notifications.#{@event}.body", **template_params)
    end

    def template_params
      tz    = TimezoneResolver.zone(@space)
      dt    = @appointment.scheduled_at&.in_time_zone(tz)
      date  = dt ? I18n.l(dt.to_date, format: :long) : "—"
      time  = dt ? dt.strftime("%H:%M") : "—"
      {
        customer_name: @appointment.customer&.name.presence || "A customer",
        date:          date,
        time:          time
      }
    end
  end
end
