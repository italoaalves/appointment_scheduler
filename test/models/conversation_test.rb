# frozen_string_literal: true

require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  def valid_conversation
    Conversation.new(
      space: spaces(:one),
      channel: :whatsapp,
      status: :needs_reply,
      priority: :normal,
      external_id: "wa_new_001",
      contact_identifier: "+5511999990099"
    )
  end

  # --- Validations ---

  test "valid with required fields" do
    assert valid_conversation.valid?
  end

  test "invalid without channel" do
    c = valid_conversation
    c.channel = nil
    assert_not c.valid?
    assert c.errors[:channel].any?
  end

  test "invalid without external_id" do
    c = valid_conversation
    c.external_id = nil
    assert_not c.valid?
  end

  test "invalid without contact_identifier" do
    c = valid_conversation
    c.contact_identifier = nil
    assert_not c.valid?
  end

  test "external_id must be unique per space and channel" do
    existing = conversations(:needs_reply_one)
    dup = valid_conversation
    dup.external_id = existing.external_id
    dup.channel = existing.channel
    assert_not dup.valid?
    assert dup.errors[:external_id].any?
  end

  test "same external_id allowed for different space" do
    existing = conversations(:needs_reply_one)
    dup = valid_conversation
    dup.space = spaces(:two)
    dup.external_id = existing.external_id
    dup.channel = existing.channel
    assert dup.valid?
  end

  test "same external_id allowed for different channel" do
    existing = conversations(:needs_reply_one)
    dup = valid_conversation
    dup.external_id = existing.external_id
    dup.channel = :email
    assert dup.valid?
  end

  # --- Enums ---

  test "channel enum values" do
    assert_equal 0, Conversation.channels[:whatsapp]
    assert_equal 1, Conversation.channels[:email]
    assert_equal 2, Conversation.channels[:sms]
    assert_equal 3, Conversation.channels[:instagram]
    assert_equal 4, Conversation.channels[:messenger]
  end

  test "status enum values" do
    assert_equal 0, Conversation.statuses[:automated]
    assert_equal 1, Conversation.statuses[:needs_reply]
    assert_equal 2, Conversation.statuses[:open]
    assert_equal 3, Conversation.statuses[:pending]
    assert_equal 4, Conversation.statuses[:resolved]
    assert_equal 5, Conversation.statuses[:closed]
  end

  test "priority enum values" do
    assert_equal 0, Conversation.priorities[:low]
    assert_equal 1, Conversation.priorities[:normal]
    assert_equal 2, Conversation.priorities[:high]
    assert_equal 3, Conversation.priorities[:urgent]
  end

  # --- Scopes ---

  test "active scope returns needs_reply, open, and pending" do
    active = Conversation.active
    assert_includes active, conversations(:needs_reply_one)
    assert_includes active, conversations(:open_with_messages)
    assert_not_includes active, conversations(:automated_one)
  end

  test "for_default_inbox excludes automated conversations" do
    inbox = Conversation.for_default_inbox
    assert_not_includes inbox, conversations(:automated_one)
    assert_includes inbox, conversations(:needs_reply_one)
  end

  test "needing_attention matches for_default_inbox" do
    assert_equal Conversation.needing_attention.to_a, Conversation.for_default_inbox.to_a
  end

  # --- session_active? ---

  test "session_active? returns true when session_expires_at is in the future" do
    c = conversations(:needs_reply_one)
    c.session_expires_at = 1.hour.from_now
    assert c.session_active?
  end

  test "session_active? returns false when session_expires_at is in the past" do
    c = conversations(:needs_reply_one)
    c.session_expires_at = 1.hour.ago
    assert_not c.session_active?
  end

  test "session_active? returns false when session_expires_at is nil" do
    c = conversations(:automated_one)
    c.session_expires_at = nil
    assert_not c.session_active?
  end

  # --- Tenant isolation ---

  test "conversations belong to a space" do
    c = conversations(:needs_reply_one)
    assert_equal spaces(:one), c.space
  end

  test "conversations from different spaces are isolated" do
    space_one_ids = spaces(:one).conversations.pluck(:id)
    space_two_ids = spaces(:two).conversations.pluck(:id)
    assert_empty (space_one_ids & space_two_ids)
  end

  # --- Associations ---

  test "belongs to customer optionally" do
    assert_not_nil conversations(:needs_reply_one).customer
    assert_nil conversations(:automated_one).customer
  end

  test "has many conversation_messages" do
    c = conversations(:open_with_messages)
    assert c.conversation_messages.count >= 2
  end
end
