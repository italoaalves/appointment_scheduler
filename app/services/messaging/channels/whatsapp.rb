# frozen_string_literal: true

module Messaging
  module Channels
    class Whatsapp < Base
      def deliver(to:, body:, subject: nil, template: nil, **opts)
        phone = resolve_phone(to)
        raise Messaging::DeliveryError, "WhatsApp requires recipient phone" if phone.blank?

        client = if opts[:space]
          ::Whatsapp::Client.for_space(opts[:space])
        else
          ::Whatsapp::Client.new(phone_number_id: opts[:phone_number_id])
        end

        result = if template
          client.send_template(
            to:            phone,
            template_name: template[:name],
            language:      template[:language] || "pt_BR",
            components:    template[:components] || []
          )
        else
          client.send_text(to: phone, body: body)
        end

        record_outbound_message(to, result, template, body, opts)

        { success: true, whatsapp_message_id: result.dig("messages", 0, "id") }
      rescue ::Whatsapp::Client::ApiError => e
        raise Messaging::DeliveryError, e.message
      end

      private

      def resolve_phone(to)
        return to.presence if to.is_a?(String)
        return to.phone    if to.respond_to?(:phone)

        nil
      end

      def record_outbound_message(recipient, result, template, body, opts)
        wamid = result.dig("messages", 0, "id")
        return unless wamid

        space = Current.space || (recipient.respond_to?(:space) ? recipient.space : nil)
        return unless space

        phone = resolve_phone(recipient)
        conversation = space.whatsapp_conversations.find_or_create_by!(
          wa_id: phone.to_s.gsub(/\D/, "")
        ) do |conv|
          conv.customer_phone = phone
          conv.customer_name  = recipient.respond_to?(:name) ? recipient.name : nil
        end

        conversation.whatsapp_messages.create!(
          wamid:        wamid,
          direction:    :outbound,
          body:         body,
          message_type: template ? "template" : "text",
          status:       :pending,
          metadata:     template ? { "template_name" => template[:name] } : {}
        )

        conversation.update!(last_message_at: Time.current)
      rescue => e
        Rails.logger.error("[Messaging::Channels::Whatsapp] Failed to record outbound message: #{e.message}")
      end
    end
  end
end
