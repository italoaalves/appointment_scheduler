# frozen_string_literal: true

require "test_helper"

class Inbox::ChannelRegistryTest < ActiveSupport::TestCase
  test "resolves whatsapp channel" do
    channel = Inbox::ChannelRegistry.for(:whatsapp)
    assert_instance_of Inbox::Channels::Whatsapp, channel
  end

  test "resolves email channel" do
    channel = Inbox::ChannelRegistry.for(:email)
    assert_instance_of Inbox::Channels::Email, channel
  end

  test "resolves sms channel" do
    channel = Inbox::ChannelRegistry.for(:sms)
    assert_instance_of Inbox::Channels::Sms, channel
  end

  test "resolves instagram channel" do
    channel = Inbox::ChannelRegistry.for(:instagram)
    assert_instance_of Inbox::Channels::Instagram, channel
  end

  test "resolves messenger channel" do
    channel = Inbox::ChannelRegistry.for(:messenger)
    assert_instance_of Inbox::Channels::Messenger, channel
  end

  test "raises ArgumentError for unknown channel" do
    assert_raises(ArgumentError) { Inbox::ChannelRegistry.for(:telegram) }
  end

  test "resolves from string key" do
    channel = Inbox::ChannelRegistry.for("whatsapp")
    assert_instance_of Inbox::Channels::Whatsapp, channel
  end
end
