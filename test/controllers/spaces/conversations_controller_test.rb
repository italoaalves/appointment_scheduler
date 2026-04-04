# frozen_string_literal: true

require "test_helper"

module Spaces
  class ConversationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager     = users(:manager)
      @manager_two = users(:manager_two)
      @secretary   = users(:secretary)
      @conversation = conversations(:needs_reply_one)
      @open_conversation = conversations(:open_with_messages)
    end

    # ============ INDEX ============

    test "requires inbox access — expired subscription blocks" do
      subscription = subscriptions(:one)
      subscription.update_column(:status, 4) # expired

      sign_in @manager
      get spaces_inbox_index_path

      assert_redirected_to settings_billing_path
      assert_equal I18n.t("inbox.access_denied"), flash[:alert]

      # restore
      subscription.update_column(:status, 0)
    end

    test "index lists conversations for current space" do
      sign_in @manager

      get spaces_inbox_index_path

      assert_response :success
      assert_includes response.body, @conversation.contact_name
    end

    test "index hides automated conversations by default" do
      sign_in @manager

      get spaces_inbox_index_path

      assert_response :success
      refute_includes response.body, "Bot Trigger"
    end

    test "index shows all conversations with all=1" do
      sign_in @manager

      get spaces_inbox_index_path(all: "1")

      assert_response :success
      assert_includes response.body, "Bot Trigger"
      assert_includes response.body, @conversation.contact_name
    end

    test "index filters by channel" do
      sign_in @manager

      get spaces_inbox_index_path(channel: "whatsapp")

      assert_response :success
      # Both needs_reply_one and open_with_messages are whatsapp + active
      assert_includes response.body, @conversation.contact_name
    end

    test "index tenant isolation — cannot see other space conversations" do
      sign_in @manager_two

      get spaces_inbox_index_path

      assert_response :success
      refute_includes response.body, @conversation.contact_name
    end

    test "index filters by status" do
      sign_in @manager

      get spaces_inbox_index_path(all: "1", status: "open")

      assert_response :success
      assert_includes response.body, @open_conversation.contact_name
      refute_includes response.body, @conversation.contact_name
    end

    test "index filters by priority — high returns no results" do
      sign_in @manager

      get spaces_inbox_index_path(priority: "high")

      assert_response :success
      # open_with_messages has high priority but check
      refute_includes response.body, @conversation.contact_name
    end

    test "index filters by customer" do
      sign_in @manager

      get spaces_inbox_index_path(customer_id: customers(:one).id)

      assert_response :success
      assert_includes response.body, @conversation.contact_name
    end

    test "index filters by assigned_to" do
      sign_in @manager

      get spaces_inbox_index_path(assigned_to: @manager.id)

      assert_response :success
      # No conversations are assigned to manager in fixtures
      refute_includes response.body, @conversation.contact_name
    end

    test "index filters by unassigned" do
      sign_in @manager

      get spaces_inbox_index_path(assigned_to: "none")

      assert_response :success
      assert_includes response.body, @conversation.contact_name
    end

    test "index filters by unread" do
      sign_in @manager

      get spaces_inbox_index_path(unread: "true")

      assert_response :success
      # needs_reply_one is unread: true
      assert_includes response.body, @conversation.contact_name
      # open_with_messages is unread: false
      refute_includes response.body, @open_conversation.contact_name
    end

    # ============ SHOW ============

    test "show displays messages and marks conversation as read" do
      @conversation.update!(unread: true)
      sign_in @manager

      get spaces_inbox_path(@conversation)

      assert_response :success
      assert_not @conversation.reload.unread
    end

    test "show returns 404 for conversation belonging to another space" do
      sign_in @manager_two

      get spaces_inbox_path(@conversation)

      assert_response :not_found
    end

    # ============ REPLY ============

    test "reply requires write_inbox permission" do
      # secretary has access_space_dashboard but NOT write_inbox
      sign_in @secretary

      post reply_spaces_inbox_path(@conversation), params: { reply: { body: "Test reply" } }

      assert_equal I18n.t("inbox.write_denied"), flash[:alert]
      assert_redirected_to spaces_inbox_index_path
    end

    test "reply creates outbound message and redirects 303" do
      @conversation.update!(session_expires_at: 23.hours.from_now)
      sign_in @manager

      mock_result = { "messages" => [ { "id" => "wamid.NEW123" } ] }
      fake_client = Object.new
      fake_client.define_singleton_method(:send_text) { |**| mock_result }

      assert_difference "@conversation.conversation_messages.count" do
        Whatsapp::Client.stub(:for_space, fake_client) do
          post reply_spaces_inbox_path(@conversation), params: { reply: { body: "Olá!" } }
        end
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_equal 303, response.status
      msg = @conversation.conversation_messages.outbound.last
      assert_equal "Olá!", msg.body
      assert_equal "wamid.NEW123", msg.external_message_id
    end

    test "reply redirects with alert when body is blank" do
      @conversation.update!(session_expires_at: 23.hours.from_now)
      sign_in @manager

      assert_no_difference "@conversation.conversation_messages.count" do
        post reply_spaces_inbox_path(@conversation), params: { reply: { body: "   " } }
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_not_nil flash[:alert]
    end

    test "reply redirects with alert when session is expired" do
      @conversation.update!(session_expires_at: 1.hour.ago)
      sign_in @manager

      assert_no_difference "@conversation.conversation_messages.count" do
        post reply_spaces_inbox_path(@conversation), params: { reply: { body: "Olá!" } }
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_not_nil flash[:alert]
    end

    # ============ UPDATE ============

    test "update successfully updates conversation" do
      sign_in @manager

      patch spaces_inbox_path(@conversation), params: { conversation: { priority: :high, status: :pending } }

      assert_redirected_to spaces_inbox_path(@conversation)
      @conversation.reload
      assert_equal "high", @conversation.priority
      assert_equal "pending", @conversation.status
    end

    test "update shows error on failure" do
      sign_in @manager

      patch spaces_inbox_path(@conversation), params: { conversation: { priority: "invalid" } }

      assert_equal I18n.t("spaces.conversations.update_failed"), flash[:alert]
      assert_redirected_to spaces_inbox_path(@conversation)
    end

    # ============ ASSIGN ============

    test "assign successfully assigns conversation" do
      sign_in @manager

      patch assign_spaces_inbox_path(@conversation), params: { conversation: { assigned_to_id: @manager.id } }

      assert_redirected_to spaces_inbox_path(@conversation)
      @conversation.reload
      assert_equal @manager.id, @conversation.assigned_to_id
    end

    # ============ RESOLVE ============

    test "resolve successfully resolves conversation" do
      sign_in @manager

      patch resolve_spaces_inbox_path(@conversation)

      assert_redirected_to spaces_inbox_index_path
      @conversation.reload
      assert_equal "resolved", @conversation.status
    end

    # ============ REOPEN ============

    test "reopen successfully reopens conversation" do
      @conversation.update!(status: :resolved)
      sign_in @manager

      patch reopen_spaces_inbox_path(@conversation)

      assert_redirected_to spaces_inbox_path(@conversation)
      @conversation.reload
      assert_equal "needs_reply", @conversation.status
    end
  end
end
