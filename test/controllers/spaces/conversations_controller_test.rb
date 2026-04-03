# frozen_string_literal: true

require "test_helper"

module Spaces
  class ConversationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager  = users(:manager)
      @manager_two = users(:manager_two)
      @conversation = conversations(:needs_reply_one)
      @open_conversation = conversations(:open_with_messages)
    end

    # ============ INDEX ============

    test "requires inbox access" do
      # Subscription is needed for inbox access
      Current.stubs(:subscription).returns(nil)

      sign_in @manager
      get spaces_conversations_path

      assert_equal "Acesso à caixa de entrada bloqueado. Faça upgrade do seu plano.", flash[:alert]
      assert_redirected_to settings_billing_path
    end

    test "index lists conversations for current space" do
      sign_in @manager

      get spaces_conversations_path

      assert_response :success
      assert_includes response.body, @conversation.contact_name
    end

    test "index hides automated conversations by default" do
      sign_in @manager

      get spaces_conversations_path

      assert_response :success
      # automated_one is an automated conversation, should not be in list
      refute_includes response.body, "Bot Trigger"
    end

    test "index shows all conversations with all=1" do
      sign_in @manager

      get spaces_conversations_path(all: "1")

      assert_response :success
      assert_includes response.body, "Bot Trigger"
      assert_includes response.body, @conversation.contact_name
    end

    test "index filters by channel" do
      sign_in @manager

      get spaces_conversations_path(channel: "whatsapp")

      assert_response :success
      assert_equal 1, assigns(:conversations).count
    end

    test "index tenant isolation — cannot see other space conversations" do
      sign_in @manager_two

      get spaces_conversations_path

      assert_response :success
      refute_includes response.body, @conversation.contact_name
    end

    test "index filters by status" do
      sign_in @manager

      get spaces_conversations_path(all: "1", status: "open")

      assert_response :success
      assert_equal 1, assigns(:conversations).count
      assert_equal "open", assigns(:conversations).first.status
    end

    test "index filters by priority" do
      sign_in @manager

      get spaces_conversations_path(priority: "high")

      assert_response :success
      assert_equal 0, assigns(:conversations).count

      get spaces_conversations_path(priority: "normal")

      assert_response :success
      assert_equal 2, assigns(:conversations).count
    end

    test "index filters by customer" do
      sign_in @manager

      get spaces_conversations_path(customer_id: customers(:one).id)

      assert_response :success
      assert_equal 1, assigns(:conversations).count
    end

    test "index filters by assigned_to" do
      sign_in @manager

      get spaces_conversations_path(assigned_to: @manager.id)

      assert_response :success
      assert_equal 0, assigns(:conversations).count
    end

    test "index filters by unassigned" do
      sign_in @manager

      get spaces_conversations_path(assigned_to: "none")

      assert_response :success
      assert_equal 2, assigns(:conversations).count
    end

    test "index filters by unread" do
      sign_in @manager

      get spaces_conversations_path(unread: "true")

      assert_response :success
      assert_equal 1, assigns(:conversations).count
    end

    # ============ SHOW ============

    test "show displays messages and marks conversation as read" do
      @conversation.update!(unread: true)
      sign_in @manager

      get spaces_conversation_path(@conversation)

      assert_response :success
      assert_not @conversation.reload.unread
    end

    test "show returns 404 for conversation belonging to another space" do
      sign_in @manager_two

      get spaces_conversation_path(@conversation)

      assert_response :not_found
    end

    # ============ REPLY ============

    test "reply requires write_inbox permission" do
      @manager.update!(permission_names: [])
      sign_in @manager

      post spaces_conversation_reply_path(@conversation), params: { reply: { body: "Test reply" } }

      assert_equal "Permissão insuficiente para responder. Entre em contato com o administrador.", flash[:alert]
      assert_redirected_to spaces_conversations_path
    end

    test "reply creates outbound message and redirects 303" do
      @conversation.update!(session_expires_at: 23.hours.from_now)
      sign_in @manager

      mock_result = { "messages" => [ { "id" => "wamid.NEW123" } ] }
      fake_client = Object.new
      fake_client.define_singleton_method(:send_text) { |**| mock_result }

      assert_difference "@conversation.conversation_messages.count" do
        Whatsapp::Client.stub(:for_space, fake_client) do
          post spaces_conversation_reply_path(@conversation), params: { reply: { body: "Olá!" } }
        end
      end

      assert_redirected_to spaces_conversation_path(@conversation)
      assert_equal 303, response.status
      msg = @conversation.conversation_messages.outbound.last
      assert_equal "Olá!", msg.body
      assert_equal "wamid.NEW123", msg.external_message_id
    end

    test "reply redirects with alert when body is blank" do
      @conversation.update!(session_expires_at: 23.hours.from_now)
      sign_in @manager

      assert_no_difference "@conversation.conversation_messages.count" do
        post spaces_conversation_reply_path(@conversation), params: { reply: { body: "   " } }
      end

      assert_redirected_to spaces_conversation_path(@conversation)
      assert_not_nil flash[:alert]
    end

    test "reply redirects with alert when session is expired" do
      @conversation.update!(session_expires_at: 1.hour.ago)
      sign_in @manager

      assert_no_difference "@conversation.conversation_messages.count" do
        post spaces_conversation_reply_path(@conversation), params: { reply: { body: "Olá!" } }
      end

      assert_redirected_to spaces_conversation_path(@conversation)
      assert_not_nil flash[:alert]
    end

    # ============ UPDATE ============

    test "update successfully updates conversation" do
      sign_in @manager

      patch spaces_conversation_path(@conversation), params: { conversation: { priority: :high, status: :pending } }

      assert_redirected_to spaces_conversation_path(@conversation)
      @conversation.reload
      assert_equal "high", @conversation.priority
      assert_equal "pending", @conversation.status
    end

    test "update shows error on failure" do
      sign_in @manager

      patch spaces_conversation_path(@conversation), params: { conversation: { priority: "invalid" } }

      assert_equal "Não foi possível atualizar a conversa. Tente novamente.", flash[:alert]
      assert_redirected_to spaces_conversation_path(@conversation)
    end

    # ============ ASSIGN ============

    test "assign successfully assigns conversation" do
      sign_in @manager

      patch spaces_conversation_assign_path(@conversation), params: { conversation: { assigned_to_id: @manager.id } }

      assert_redirected_to spaces_conversation_path(@conversation)
      @conversation.reload
      assert_equal @manager.id, @conversation.assigned_to_id
    end

    # ============ RESOLVE ============

    test "resolve successfully resolves conversation" do
      sign_in @manager

      patch spaces_conversation_resolve_path(@conversation)

      assert_redirected_to spaces_conversations_path
      @conversation.reload
      assert_equal "resolved", @conversation.status
    end

    # ============ REOPEN ============

    test "reopen successfully reopens conversation" do
      @conversation.update!(status: :resolved)
      sign_in @manager

      patch spaces_conversation_reopen_path(@conversation)

      assert_redirected_to spaces_conversation_path(@conversation)
      @conversation.reload
      assert_equal "needs_reply", @conversation.status
    end
  end
end
