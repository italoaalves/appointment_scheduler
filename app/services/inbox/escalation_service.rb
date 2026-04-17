# frozen_string_literal: true

module Inbox
  class EscalationService
    def self.call(appointment:, reason:)
      new(appointment: appointment, reason: reason).call
    end

    def initialize(appointment:, reason:)
      @appointment = appointment
      @reason = reason.to_s
      @space = appointment.space
      @customer = appointment.customer
    end

    def call
      conversation = find_or_initialize_conversation
      conversation.assign_attributes(conversation_attributes)
      conversation.metadata = conversation.metadata.to_h.merge(escalation_metadata)
      conversation.save!
      conversation
    end

    private

    def find_or_initialize_conversation
      @space.conversations.where(channel: :whatsapp, customer: @customer)
            .order(last_message_at: :desc, id: :desc)
            .first_or_initialize
    end

    def conversation_attributes
      {
        customer: @customer,
        channel: :whatsapp,
        status: :needs_reply,
        priority: :normal,
        external_id: conversation_external_id,
        contact_identifier: @customer&.phone || "unknown",
        contact_name: @customer&.name,
        last_message_at: Time.current,
        unread: true
      }
    end

    def escalation_metadata
      metadata = {
        "appointment_id" => @appointment.id,
        "reason" => @reason
      }

      booking_link = booking_link_details
      return metadata if booking_link.empty?

      metadata.merge(booking_link)
    end

    def booking_link_details
      personalized_link = @space.personalized_scheduling_link
      if personalized_link.present?
        context = BookingContext::PersonalizedBookingContext.new(personalized_link)
        return {
          "booking_context" => context.confirmation_context,
          "booking_url" => context.form_url
        }
      end

      scheduling_link = @space.scheduling_links.usable.order(created_at: :desc, id: :desc).first
      return {} unless scheduling_link

      context = BookingContext::TokenBookingContext.new(scheduling_link)
      {
        "booking_context" => context.confirmation_context,
        "booking_url" => context.form_url
      }
    end

    def conversation_external_id
      "scheduling:customer:#{@customer&.id || 'unknown'}"
    end
  end
end
