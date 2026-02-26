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
    end

    def call
      strategy_class = CHANNELS[@channel]
      raise ArgumentError, "Unknown channel: #{@channel}. Available: #{CHANNELS.keys.join(', ')}" unless strategy_class

      strategy_class.new.deliver(
        to: @to,
        body: @body,
        subject: @subject,
        **@opts
      )
    rescue Messaging::DeliveryError => e
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

      Rails.logger.error(
        "[Messaging] twilio_transport_error" \
        " channel=#{@channel}" \
        " to=#{@to.inspect}" \
        " error_class=#{e.class}" \
        " error=#{e.message}"
      )
      { success: false, error: e.message }
    end
  end
end
