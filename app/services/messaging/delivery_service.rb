# frozen_string_literal: true

module Messaging
  class DeliveryService
    CHANNELS = {
      email: Channels::Email,
      whatsapp: Channels::Whatsapp
    }.freeze

    def self.call(channel:, to:, body:, subject: nil, **opts)
      new(channel: channel, to: to, body: body, subject: subject, **opts).call
    end

    def initialize(channel:, to:, body:, subject: nil, **opts)
      @channel = channel.to_sym
      @to = to
      @body = body
      @subject = subject
      @opts = opts
      @credit_deduction = nil
    end

    def call
      strategy_class = CHANNELS[@channel]
      raise ArgumentError, "Unknown channel: #{@channel}. Available: #{CHANNELS.keys.join(', ')}" unless strategy_class

      if @channel == :whatsapp
        space = resolve_space_from_recipient
        unless Billing::CreditManager.sufficient?(space: space)
          return { success: false, error: "insufficient_whatsapp_credits" }
        end

        @credit_deduction = Billing::CreditManager.deduct(space: space)
        unless @credit_deduction[:success]
          return { success: false, error: "insufficient_whatsapp_credits" }
        end
      end

      strategy_class.new.deliver(
        to: @to,
        body: @body,
        subject: @subject,
        **@opts
      )
    rescue Messaging::DeliveryError => e
      refund_credit_if_needed
      Rails.logger.error(
        "[Messaging] delivery_failed" \
        " channel=#{@channel}" \
        " to=#{@to.inspect}" \
        " error_class=#{e.class}" \
        " error=#{e.message}"
      )
      { success: false, error: e.message }
    rescue => e
      raise unless defined?(Twilio::REST::TwilioError) && e.is_a?(Twilio::REST::TwilioError)

      refund_credit_if_needed
      Rails.logger.error(
        "[Messaging] twilio_transport_error" \
        " channel=#{@channel}" \
        " to=#{@to.inspect}" \
        " error_class=#{e.class}" \
        " error=#{e.message}"
      )
      { success: false, error: e.message }
    end

    private

    def resolve_space_from_recipient
      return Current.space if Current.space.present?

      case @to
      when Customer then @to.space
      when User     then @to.space
      else
        raise ArgumentError, "Cannot resolve space from #{@to.class}"
      end
    end

    def refund_credit_if_needed
      return unless @credit_deduction&.dig(:success)

      space = resolve_space_from_recipient
      Billing::CreditManager.refund(space: space, source: @credit_deduction[:source])
    end
  end
end
