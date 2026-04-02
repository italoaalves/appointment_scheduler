# frozen_string_literal: true

module Inbox
  class CheckSlaBreachesJob < ApplicationJob
    queue_as :default

    def perform
      Conversation
        .where(sla_breached: false, first_response_at: nil)
        .where.not(sla_deadline_at: nil)
        .where(status: [ :needs_reply, :open, :pending ])
        .where("sla_deadline_at < ?", Time.current)
        .find_each do |conversation|
          conversation.update_column(:sla_breached, true)
          notify_sla_breach(conversation)
        end
    end

    private

    def notify_sla_breach(conversation)
      space = conversation.space
      recipient_ids = sla_recipient_ids(conversation, space)
      return if recipient_ids.empty?

      now = Time.current
      records = recipient_ids.map do |user_id|
        {
          user_id: user_id,
          title: I18n.t("notifications.in_app.sla_breach.title"),
          body: I18n.t("notifications.in_app.sla_breach.body",
                       name: conversation.contact_name.presence || conversation.contact_identifier),
          notifiable_type: "Conversation",
          notifiable_id: conversation.id,
          event_type: "sla_breach",
          read: false,
          created_at: now,
          updated_at: now
        }
      end

      Notification.insert_all(records)
    end

    def sla_recipient_ids(conversation, space)
      if conversation.assigned_to_id.present?
        [ conversation.assigned_to_id ]
      else
        (space.space_memberships.pluck(:user_id) + [ space.owner_id ]).compact.uniq
      end
    end
  end
end
