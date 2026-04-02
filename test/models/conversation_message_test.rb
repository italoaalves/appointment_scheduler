# frozen_string_literal: true

require "test_helper"

class ConversationMessageTest < ActiveSupport::TestCase
  def valid_message
    ConversationMessage.new(
      conversation: conversations(:needs_reply_one),
      direction: :inbound,
      body: "Hello"
    )
  end

  # --- Validations ---

  test "valid with required fields" do
    assert valid_message.valid?
  end

  test "invalid without direction" do
    m = valid_message
    m.direction = nil
    assert_not m.valid?
    assert m.errors[:direction].any?
  end

  test "invalid without conversation" do
    m = valid_message
    m.conversation = nil
    assert_not m.valid?
  end

  # --- Enums ---

  test "direction enum values" do
    assert_equal 0, ConversationMessage.directions[:inbound]
    assert_equal 1, ConversationMessage.directions[:outbound]
  end

  test "status enum values" do
    assert_equal 0, ConversationMessage.statuses[:pending]
    assert_equal 1, ConversationMessage.statuses[:sent]
    assert_equal 2, ConversationMessage.statuses[:delivered]
    assert_equal 3, ConversationMessage.statuses[:read]
    assert_equal 4, ConversationMessage.statuses[:failed]
  end

  # --- Scopes ---

  test "chronological scope orders by created_at ascending" do
    msgs = conversations(:open_with_messages).conversation_messages.chronological
    timestamps = msgs.map(&:created_at)
    assert_equal timestamps.sort, timestamps
  end

  # --- Associations ---

  test "belongs to conversation" do
    m = conversation_messages(:inbound_question)
    assert_equal conversations(:needs_reply_one), m.conversation
  end

  test "sent_by is optional" do
    m = conversation_messages(:inbound_question)
    assert_nil m.sent_by
  end

  test "outbound message can have sent_by user" do
    m = conversation_messages(:outbound_reply)
    assert_equal users(:manager), m.sent_by
  end

  # --- Defaults ---

  test "credit_cost defaults to 0" do
    m = valid_message.tap(&:save!)
    assert_equal 0, m.credit_cost
  end
end
