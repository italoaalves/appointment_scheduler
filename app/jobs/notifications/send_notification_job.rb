# frozen_string_literal: true

module Notifications
  class SendNotificationJob < ApplicationJob
    queue_as :default

    discard_on(ActiveRecord::RecordNotFound) { |job, err| Rails.logger.warn("[Notifications] appointment not found id=#{job.arguments.first&.dig(:appointment_id)}") }

    def perform(event:, appointment_id:)
      appointment = Appointment.find(appointment_id)
      return if event.to_s == "appointment_booked" && appointment.space&.owner.blank?
      return if %w[appointment_confirmed appointment_cancelled appointment_rescheduled].include?(event.to_s) && appointment.customer_id.blank?

      Current.space = appointment.space
      Spaces::NotificationDispatcher.call(event: event.to_sym, appointment: appointment)
    ensure
      Current.reset
    end
  end
end
