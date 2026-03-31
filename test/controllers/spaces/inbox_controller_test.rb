# frozen_string_literal: true

require "test_helper"

module Spaces
  class InboxControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager  = users(:manager)    # spaces(:one) — Essential plan, trialing (no WhatsApp)
      @manager2 = users(:manager_two) # spaces(:two) — Pro plan, active (WhatsApp included)
      @conversation = whatsapp_conversations(:one)
      # Pro plan gating requires a MessageCredit row
      Billing::MessageCredit.find_or_create_by!(space: spaces(:two)) do |c|
        c.balance = 0
        c.monthly_quota_remaining = 200
      end
    end

    # ── plan gating ──────────────────────────────────────────────────────────

    test "index redirects to billing when space has no WhatsApp feature" do
      sign_in @manager

      get spaces_inbox_index_path

      assert_redirected_to settings_billing_path
    end

    test "show redirects to billing when space has no WhatsApp feature" do
      sign_in @manager

      get spaces_inbox_path(@conversation)

      assert_redirected_to settings_billing_path
    end

    # ── index ─────────────────────────────────────────────────────────────────

    test "index lists conversations for current space" do
      @conversation.update!(space: spaces(:two))
      sign_in @manager2

      get spaces_inbox_index_path

      assert_response :success
      assert_includes response.body, @conversation.customer_name
    end

    test "index tenant isolation — cannot see other space conversations" do
      # conversation belongs to space :one; manager2 owns space :two
      sign_in @manager2

      get spaces_inbox_index_path

      assert_response :success
      refute_includes response.body, @conversation.customer_name
    end

    # ── show ──────────────────────────────────────────────────────────────────

    test "show displays messages and marks conversation as read" do
      @conversation.update!(space: spaces(:two), unread: true)
      sign_in @manager2

      get spaces_inbox_path(@conversation)

      assert_response :success
      assert_not @conversation.reload.unread
    end

    test "show returns 404 for conversation belonging to another space" do
      # conversation belongs to space :one; manager2 owns space :two
      sign_in @manager2

      get spaces_inbox_path(@conversation)

      assert_response :not_found
    end

    # ── reply ─────────────────────────────────────────────────────────────────

    test "reply creates outbound message and redirects 303" do
      @conversation.update!(space: spaces(:two), session_expires_at: 23.hours.from_now)
      sign_in @manager2

      mock_result = { "messages" => [ { "id" => "wamid.NEW123" } ] }
      fake_client = Object.new
      fake_client.define_singleton_method(:send_text) { |**| mock_result }

      assert_difference "@conversation.whatsapp_messages.count" do
        Whatsapp::Client.stub(:new, fake_client) do
          post reply_spaces_inbox_path(@conversation), params: { body: "Olá!" }
        end
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_equal 303, response.status
      msg = @conversation.whatsapp_messages.outbound.last
      assert_equal "Olá!", msg.body
      assert_equal "wamid.NEW123", msg.wamid
    end

    test "reply redirects with alert when body is blank" do
      @conversation.update!(space: spaces(:two), session_expires_at: 23.hours.from_now)
      sign_in @manager2

      assert_no_difference "@conversation.whatsapp_messages.count" do
        post reply_spaces_inbox_path(@conversation), params: { body: "   " }
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_not_nil flash[:alert]
    end

    test "reply redirects with alert when session is expired" do
      @conversation.update!(space: spaces(:two), session_expires_at: 1.hour.ago)
      sign_in @manager2

      assert_no_difference "@conversation.whatsapp_messages.count" do
        post reply_spaces_inbox_path(@conversation), params: { body: "Olá!" }
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_not_nil flash[:alert]
    end

    test "reply redirects with delivery failure alert on API error" do
      @conversation.update!(space: spaces(:two), session_expires_at: 23.hours.from_now)
      sign_in @manager2

      exploding_client = Object.new
      def exploding_client.send_text(**) = raise Whatsapp::Client::ApiError.new("send failed")

      assert_no_difference "@conversation.whatsapp_messages.count" do
        Whatsapp::Client.stub(:new, exploding_client) do
          post reply_spaces_inbox_path(@conversation), params: { body: "Olá!" }
        end
      end

      assert_redirected_to spaces_inbox_path(@conversation)
      assert_not_nil flash[:alert]
    end
  end
end
