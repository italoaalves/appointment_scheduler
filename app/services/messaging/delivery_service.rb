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
    rescue Messaging::DeliveryError, StandardError => e
      { success: false, error: e.message }
    end
  end
end
