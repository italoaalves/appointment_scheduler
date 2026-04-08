# frozen_string_literal: true

require "test_helper"

class Inbox::SendTemplateReopenTest < ActiveSupport::TestCase
  def setup
    @space = spaces(:one)
    @user = users(:manager)
    @conversation = conversations(:needs_reply_one)
  end

  def call_service(conversation: @conversation, template_name: nil)
    fake_response = { "messages" => [ { "id" => "wamid.template_abc" } ] }
    fake_client = Object.new
    fake_client.define_singleton_method(:send_template) { |**_| fake_response }

    Whatsapp::Client.stub(:for_space, fake_client) do
      Inbox::SendTemplateReopen.new(
        conversation: conversation,
        sent_by: @user,
        space: @space,
        template_name: template_name
      ).call
    end
  end

  test "creates outbound template message and returns success" do
    @conversation.update!(session_expires_at: 1.hour.ago)

    result = call_service

    assert result.success?
    assert_equal "template", result.message.message_type
    assert_equal @user, result.message.sent_by
    assert_equal "wamid.template_abc", result.message.external_message_id
  end

  test "deducts one credit and updates conversation total" do
    @conversation.update!(session_expires_at: 1.hour.ago)
    credit = Billing::MessageCredit.find_by!(space: @space)

    assert_difference -> { credit.reload.balance + credit.reload.monthly_quota_remaining }, -1 do
      call_service
    end

    assert_equal 1, @conversation.reload.credit_cost_total
  end

  test "moves conversation to open after sending template" do
    @conversation.update!(session_expires_at: 1.hour.ago)

    call_service

    assert @conversation.reload.open?
  end

  test "returns failure when channel does not support template reopen" do
    conversation = conversations(:open_with_messages)
    conversation.update!(channel: :email)

    result = call_service(conversation: conversation)

    refute result.success?
    assert_equal I18n.t("spaces.conversations.detail.template_not_supported"), result.error
  end

  test "returns failure when template is not configured" do
    @conversation.update!(session_expires_at: 1.hour.ago)

    Inbox::Channels::Whatsapp.stub(:default_reengagement_template, nil) do
      result = call_service

      refute result.success?
      assert_equal I18n.t("spaces.conversations.detail.template_not_configured"), result.error
    end
  end

  test "creates failed outbound template message and refunds credit when provider send fails" do
    @conversation.update!(session_expires_at: 1.hour.ago)
    credit = Billing::MessageCredit.find_by!(space: @space)
    fake_client = Object.new
    fake_client.define_singleton_method(:send_template) { |**| raise Whatsapp::Client::ApiError.new("boom") }

    result = nil
    assert_no_difference -> { credit.reload.balance + credit.reload.monthly_quota_remaining } do
      assert_difference "ConversationMessage.count", 1 do
        Whatsapp::Client.stub(:for_space, fake_client) do
          result = Inbox::SendTemplateReopen.new(
            conversation: @conversation,
            sent_by: @user,
            space: @space
          ).call
        end
      end
    end

    refute result.success?
    assert_equal I18n.t("inbox.errors.send_failed"), result.error
    message = ConversationMessage.order(:created_at).last
    assert_equal "template", message.message_type
    assert message.failed?
  end
end
