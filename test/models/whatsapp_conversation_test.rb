# frozen_string_literal: true

require "test_helper"

class WhatsappConversationTest < ActiveSupport::TestCase
  def valid_conversation
    WhatsappConversation.new(
      space: spaces(:one),
      wa_id: "5511988880001",
      customer_phone: "+5511988880001"
    )
  end

  test "validates presence of wa_id" do
    conv = valid_conversation
    conv.wa_id = nil
    assert_not conv.valid?
    assert conv.errors[:wa_id].any?
  end

  test "validates presence of customer_phone" do
    conv = valid_conversation
    conv.customer_phone = nil
    assert_not conv.valid?
    assert conv.errors[:customer_phone].any?
  end

  test "validates uniqueness of wa_id scoped to space_id" do
    existing = whatsapp_conversations(:one)
    dup = WhatsappConversation.new(
      space: existing.space,
      wa_id: existing.wa_id,
      customer_phone: "+5511000000000"
    )
    assert_not dup.valid?
    assert dup.errors[:wa_id].any?
  end

  test "session_active? returns true when session_expires_at is in the future" do
    conv = valid_conversation
    conv.session_expires_at = 1.hour.from_now
    assert conv.session_active?
  end

  test "session_active? returns false when session_expires_at is in the past" do
    conv = valid_conversation
    conv.session_expires_at = 1.hour.ago
    assert_not conv.session_active?
  end

  test "session_active? returns false when session_expires_at is nil" do
    conv = valid_conversation
    conv.session_expires_at = nil
    assert_not conv.session_active?
  end

  test "unread scope returns only unread conversations" do
    whatsapp_conversations(:one).update!(unread: true)
    assert_includes WhatsappConversation.unread, whatsapp_conversations(:one)

    whatsapp_conversations(:one).update!(unread: false)
    assert_not_includes WhatsappConversation.unread, whatsapp_conversations(:one)
  end

  test "space association present" do
    conv = whatsapp_conversations(:one)
    assert_equal spaces(:one), conv.space
  end
end
