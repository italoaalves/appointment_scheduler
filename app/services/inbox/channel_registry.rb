# frozen_string_literal: true

module Inbox
  module ChannelRegistry
    CHANNELS = {
      whatsapp:  Channels::Whatsapp,
      email:     Channels::Email,
      sms:       Channels::Sms,
      instagram: Channels::Instagram,
      messenger: Channels::Messenger
    }.freeze

    def self.for(channel)
      klass = CHANNELS[channel.to_sym]
      raise ArgumentError, "Unknown channel: #{channel}" unless klass

      klass.new
    end
  end
end
