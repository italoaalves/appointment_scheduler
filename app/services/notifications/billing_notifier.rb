# frozen_string_literal: true

module Notifications
  class BillingNotifier
    def self.notify(event_type:, user:, notifiable:, params: {})
      new.notify(event_type: event_type, user: user, notifiable: notifiable, params: params)
    end

    def notify(event_type:, user:, notifiable:, params: {})
      return if user.nil?
      return if already_notified?(event_type, user, notifiable)

      Notification.create!(
        user:       user,
        notifiable: notifiable,
        event_type: event_type.to_s,
        title:      I18n.t("notifications.in_app.#{event_type}.title"),
        body:       I18n.t("notifications.in_app.#{event_type}.body", **params)
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error(
        "[Notifications] billing_notification_failed event=#{event_type} " \
        "user_id=#{user&.id} error=#{e.message}"
      )
    end

    private

    def already_notified?(event_type, user, notifiable)
      Notification.where(
        user:       user,
        notifiable: notifiable,
        event_type: event_type.to_s
      ).where("created_at > ?", 24.hours.ago).exists?
    end
  end
end
