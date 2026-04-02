# frozen_string_literal: true

module Whatsapp
  class ProcessWebhookJob < ApplicationJob
    queue_as :default
    discard_on JSON::ParserError

    def perform(payload:)
      data = JSON.parse(payload)

      data.dig("entry")&.each do |entry|
        entry.dig("changes")&.each do |change|
          if change["field"] == "phone_number_quality_update"
            process_quality_update(change["value"])
            next
          end

          next unless change["field"] == "messages"

          value = change["value"]
          phone_number_id = value.dig("metadata", "phone_number_id")

          process_statuses(value["statuses"]) if value["statuses"].present?
          process_messages(value["messages"], value["contacts"], phone_number_id) if value["messages"].present?
        end
      end
    end

    private

    def process_statuses(statuses)
      statuses.each do |status_event|
        wamid      = status_event["id"]
        new_status = status_event["status"]

        message = WhatsappMessage.find_by(wamid: wamid)
        next unless message

        if new_status == "failed"
          message.update!(status: :failed, metadata: message.metadata.merge(
            "error" => status_event["errors"]&.first
          ))
          refund_credit(message)
        elsif message.status_progression_valid?(new_status)
          message.update!(status: new_status)
        end
      end
    end

    def process_messages(messages, contacts, phone_number_id)
      messages.each do |msg|
        wamid = msg["id"]
        next if WhatsappMessage.exists?(wamid: wamid)

        wa_id         = msg["from"]
        contact       = contacts&.find { |c| c["wa_id"] == wa_id }
        customer_name = contact&.dig("profile", "name")

        conversation = find_or_create_conversation(wa_id, customer_name, phone_number_id)
        next unless conversation

        conversation.whatsapp_messages.create!(
          wamid: wamid,
          direction: :inbound,
          body: extract_body(msg),
          message_type: msg["type"] || "text",
          status: :delivered,
          metadata: { "raw_type" => msg["type"] }
        )

        conversation.update!(
          last_message_at: Time.current,
          session_expires_at: 24.hours.from_now,
          unread: true,
          customer_name: customer_name.presence || conversation.customer_name
        )

        Whatsapp::NotifySpaceMembersJob.perform_later(conversation_id: conversation.id)
      end
    end

    def find_or_create_conversation(wa_id, customer_name, phone_number_id)
      whatsapp_number = WhatsappPhoneNumber.active.find_by(phone_number_id: phone_number_id)

      unless whatsapp_number
        Rails.logger.warn("[Whatsapp::ProcessWebhookJob] Unknown phone_number_id: #{phone_number_id}")
        return nil
      end

      if whatsapp_number.space
        # Tenant-owned number — route to that space, create conversation if new
        whatsapp_number.space.whatsapp_conversations.find_or_create_by!(wa_id: wa_id) do |conv|
          conv.customer_phone = "+#{wa_id}"
          conv.customer_name = customer_name
        end
      else
        # System bot — match by wa_id across all spaces (existing behavior)
        WhatsappConversation.find_by(wa_id: wa_id)
      end
    end

    def extract_body(msg)
      case msg["type"]
      when "text"        then msg.dig("text", "body")
      when "button"      then msg.dig("button", "text")
      when "interactive" then msg.dig("interactive", "button_reply", "title") ||
                              msg.dig("interactive", "list_reply", "title")
      else                    "[#{msg['type']} message]"
      end
    end

    def refund_credit(message)
      space = message.whatsapp_conversation.space
      Billing::CreditManager.new(space).refund(source: :delivery_failure)
    rescue => e
      Rails.logger.error("[Whatsapp::ProcessWebhookJob] Credit refund failed for message #{message.id}: #{e.message}")
    end

    def process_quality_update(value)
      display = value["display_phone_number"]
      digits = display&.gsub(/\D/, "")
      event = value["event"]

      whatsapp_number = WhatsappPhoneNumber.find_by(normalized_phone: digits)
      return unless whatsapp_number

      new_rating = map_quality_rating(event)
      whatsapp_number.update!(
        quality_rating: new_rating,
        metadata: whatsapp_number.metadata.merge(
          "messaging_limit" => value["current_limit"],
          "last_quality_event" => event,
          "last_quality_update_at" => Time.current.iso8601
        )
      )

      notify_quality_degradation(whatsapp_number, event) if event.in?(%w[FLAGGED RESTRICTED])
    end

    def map_quality_rating(event)
      case event
      when "FLAGGED"    then "YELLOW"
      when "RESTRICTED" then "RED"
      when "UNFLAGGED"  then "GREEN"
      else event
      end
    end

    def notify_quality_degradation(whatsapp_number, event)
      return unless whatsapp_number.space&.owner

      Notification.create!(
        user: whatsapp_number.space.owner,
        title: I18n.t("notifications.in_app.whatsapp_quality.title"),
        body: I18n.t("notifications.in_app.whatsapp_quality.body_#{event.downcase}",
                     number: whatsapp_number.display_number),
        notifiable: whatsapp_number,
        event_type: "whatsapp_quality_#{event.downcase}"
      )
    end
  end
end
