# frozen_string_literal: true

require "test_helper"

class WhatsappMessageTest < ActiveSupport::TestCase
  def valid_message
    WhatsappMessage.new(
      whatsapp_conversation: whatsapp_conversations(:one),
      direction: :inbound
    )
  end

  test "validates presence of direction" do
    msg = valid_message
    msg.direction = nil
    assert_not msg.valid?
    assert msg.errors[:direction].any?
  end

  test "enum directions: inbound=0, outbound=1" do
    assert_equal 0, WhatsappMessage.directions[:inbound]
    assert_equal 1, WhatsappMessage.directions[:outbound]
  end

  test "enum statuses: pending=0, sent=1, delivered=2, read=3, failed=4" do
    assert_equal 0, WhatsappMessage.statuses[:pending]
    assert_equal 1, WhatsappMessage.statuses[:sent]
    assert_equal 2, WhatsappMessage.statuses[:delivered]
    assert_equal 3, WhatsappMessage.statuses[:read]
    assert_equal 4, WhatsappMessage.statuses[:failed]
  end

  test "status_progression_valid? allows forward transitions" do
    msg = valid_message
    msg.status = :pending
    assert msg.status_progression_valid?(:sent)

    msg.status = :sent
    assert msg.status_progression_valid?(:delivered)

    msg.status = :delivered
    assert msg.status_progression_valid?(:read)
  end

  test "status_progression_valid? rejects backward transitions" do
    msg = valid_message
    msg.status = :delivered
    assert_not msg.status_progression_valid?(:sent)
  end

  test "status_progression_valid? always allows transition to failed" do
    msg = valid_message
    [ :pending, :sent, :delivered, :read ].each do |s|
      msg.status = s
      assert msg.status_progression_valid?(:failed), "Expected failed to be valid from #{s}"
    end
  end

  test "chronological scope orders by created_at asc" do
    assert_equal "\"whatsapp_messages\".\"created_at\" ASC", WhatsappMessage.chronological.order_values.first.to_sql
  end

  test "body is encrypted at rest" do
    message = WhatsappMessage.create!(
      whatsapp_conversation: whatsapp_conversations(:one),
      direction: :outbound,
      body: "Sensitive WhatsApp reply"
    )

    assert_equal "Sensitive WhatsApp reply", message.reload.body
    assert_not_equal "Sensitive WhatsApp reply", message.reload.ciphertext_for(:body)
  end
end
