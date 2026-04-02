# frozen_string_literal: true

module Whatsapp
  class NotifySpaceMembersJob < ApplicationJob
    queue_as :default

    def perform(conversation_id:)
      conversation = WhatsappConversation.find_by(id: conversation_id)
      return unless conversation

      space = conversation.space
      return unless space

      member_ids    = space.space_memberships.pluck(:user_id)
      recipient_ids = (member_ids + [ space.owner_id ]).compact.uniq

      display_name = conversation.customer_name.presence || conversation.customer_phone
      now = Time.current

      records = recipient_ids.map do |user_id|
        {
          user_id: user_id,
          title: I18n.t("notifications.in_app.whatsapp_message.title"),
          body: I18n.t("notifications.in_app.whatsapp_message.body", name: display_name),
          notifiable_type: "WhatsappConversation",
          notifiable_id: conversation.id,
          event_type: "whatsapp_message_received",
          read: false,
          created_at: now,
          updated_at: now
        }
      end

      Notification.insert_all(records) if records.any?
    end
  end
end
