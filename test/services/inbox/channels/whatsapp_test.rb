# frozen_string_literal: true

require "test_helper"

class Inbox::Channels::WhatsappTest < ActiveSupport::TestCase
  def setup
    @channel = Inbox::Channels::Whatsapp.new
  end

  test "is session windowed" do
    assert @channel.session_windowed?
  end

  test "can_send? returns true when session is active" do
    conversation = conversations(:needs_reply_one)
    assert @channel.can_send?(conversation)
  end

  test "can_send? returns false when session is expired" do
    conversation = conversations(:needs_reply_one)
    conversation.session_expires_at = 1.hour.ago
    refute @channel.can_send?(conversation)
  end

  test "can_send? returns false when session_expires_at is nil" do
    conversation = conversations(:needs_reply_one)
    conversation.session_expires_at = nil
    refute @channel.can_send?(conversation)
  end

  test "send_cost is 0 inside session window" do
    conversation = conversations(:needs_reply_one)
    assert_equal 0, @channel.send_cost(conversation)
  end

  test "send_cost is 1 outside session window" do
    conversation = conversations(:needs_reply_one)
    conversation.session_expires_at = 1.hour.ago
    assert_equal 1, @channel.send_cost(conversation)
  end

  test "send_blocked_reason is nil inside session window" do
    conversation = conversations(:needs_reply_one)
    assert_nil @channel.send_blocked_reason(conversation)
  end

  test "send_blocked_reason returns message when session expired" do
    conversation = conversations(:needs_reply_one)
    conversation.session_expires_at = 1.hour.ago
    assert_equal I18n.t("inbox.channels.whatsapp.session_expired"),
                 @channel.send_blocked_reason(conversation)
  end

  test "email channel can always send" do
    email_channel = Inbox::Channels::Email.new
    conversation = conversations(:needs_reply_one)
    assert email_channel.can_send?(conversation)
  end

  test "email channel send_cost is 0" do
    email_channel = Inbox::Channels::Email.new
    conversation = conversations(:needs_reply_one)
    assert_equal 0, email_channel.send_cost(conversation)
  end

  test "email channel raises NotImplementedError on send_message" do
    email_channel = Inbox::Channels::Email.new
    assert_raises(NotImplementedError) do
      email_channel.send_message(conversations(:needs_reply_one), body: "hello", sent_by: nil)
    end
  end
end
