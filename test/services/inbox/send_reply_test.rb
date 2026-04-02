# frozen_string_literal: true

require "test_helper"

class Inbox::SendReplyTest < ActiveSupport::TestCase
  def setup
    @space = spaces(:one)
    @user = users(:manager)
    @conversation = conversations(:needs_reply_one)
  end

  def call_service(conversation: @conversation, body: "Hello!")
    fake_response = { "messages" => [ { "id" => "wamid.test_abc" } ] }
    fake_client = Object.new
    fake_client.define_singleton_method(:send_text) { |**_| fake_response }

    Whatsapp::Client.stub(:for_space, fake_client) do
      Inbox::SendReply.new(
        conversation: conversation,
        body: body,
        sent_by: @user,
        space: @space
      ).call
    end
  end

  test "happy path creates outbound message and returns success" do
    result = call_service

    assert result.success?
    assert_not_nil result.message
    assert_equal "outbound", result.message.direction
    assert_equal "Hello!", result.message.body
    assert_equal @user, result.message.sent_by
  end

  test "sets first_response_at on first reply" do
    assert_nil @conversation.first_response_at
    call_service
    assert_not_nil @conversation.reload.first_response_at
  end

  test "does not overwrite first_response_at on subsequent replies" do
    first_time = 1.hour.ago
    @conversation.update!(first_response_at: first_time)
    call_service
    assert_in_delta first_time.to_i, @conversation.reload.first_response_at.to_i, 1
  end

  test "transitions conversation status to open" do
    assert @conversation.needs_reply?
    call_service
    assert @conversation.reload.open?
  end

  test "updates last_message_body on conversation" do
    call_service(body: "Updated reply text")
    assert_equal "Updated reply text", @conversation.reload.last_message_body
  end

  test "zero credit cost for WhatsApp inside session window" do
    result = call_service
    assert_equal 0, result.message.credit_cost
    assert_equal 0, @conversation.reload.credit_cost_total
  end

  test "returns failure with blocked reason when session expired" do
    @conversation.update!(session_expires_at: 1.hour.ago)
    result = Inbox::SendReply.new(
      conversation: @conversation, body: "Hi", sent_by: @user, space: @space
    ).call

    refute result.success?
    assert_equal I18n.t("inbox.channels.whatsapp.session_expired"), result.error
  end

  test "no ConversationMessage created when session expired" do
    @conversation.update!(session_expires_at: 1.hour.ago)
    count_before = ConversationMessage.count

    Inbox::SendReply.new(
      conversation: @conversation, body: "Hi", sent_by: @user, space: @space
    ).call

    assert_equal count_before, ConversationMessage.count
  end
end
