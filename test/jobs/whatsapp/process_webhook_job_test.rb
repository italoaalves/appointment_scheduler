# frozen_string_literal: true

require "test_helper"

class Whatsapp::ProcessWebhookJobTest < ActiveJob::TestCase
  def inbound_payload(wamid: "wamid.NEW001", wa_id: "5511999990001", body: "Hello!", name: "João Silva")
    {
      "entry" => [
        {
          "changes" => [
            {
              "field" => "messages",
              "value" => {
                "metadata"  => { "phone_number_id" => "123456789" },
                "contacts"  => [ { "wa_id" => wa_id, "profile" => { "name" => name } } ],
                "messages"  => [
                  {
                    "id"   => wamid,
                    "from" => wa_id,
                    "type" => "text",
                    "text" => { "body" => body }
                  }
                ]
              }
            }
          ]
        }
      ]
    }.to_json
  end

  def status_payload(wamid:, status:, errors: nil)
    event = { "id" => wamid, "status" => status }
    event["errors"] = errors if errors
    {
      "entry" => [
        {
          "changes" => [
            {
              "field" => "messages",
              "value" => {
                "metadata" => { "phone_number_id" => "123456789" },
                "statuses" => [ event ]
              }
            }
          ]
        }
      ]
    }.to_json
  end

  # ── Status updates ──────────────────────────────────────────────────────────

  test "updates message status to sent" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :pending)

    Whatsapp::ProcessWebhookJob.perform_now(payload: status_payload(wamid: msg.wamid, status: "sent"))

    assert_equal "sent", msg.reload.status
  end

  test "updates message status to delivered" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :sent)

    Whatsapp::ProcessWebhookJob.perform_now(payload: status_payload(wamid: msg.wamid, status: "delivered"))

    assert_equal "delivered", msg.reload.status
  end

  test "updates message status to read" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :delivered)

    Whatsapp::ProcessWebhookJob.perform_now(payload: status_payload(wamid: msg.wamid, status: "read"))

    assert_equal "read", msg.reload.status
  end

  test "marks message as failed and refunds credit" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :sent)
    error_info = { "code" => 131047, "title" => "Re-engagement message" }
    refunded = false

    mock_manager = Minitest::Mock.new
    mock_manager.expect(:refund, true, source: :delivery_failure)

    Billing::CreditManager.stub(:new, mock_manager) do
      Whatsapp::ProcessWebhookJob.perform_now(
        payload: status_payload(wamid: msg.wamid, status: "failed", errors: [ error_info ])
      )
    end

    msg.reload
    assert_equal "failed", msg.status
    assert_equal error_info, msg.metadata["error"]
    mock_manager.verify
  end

  test "ignores out-of-order status (sent after read)" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :read)

    Whatsapp::ProcessWebhookJob.perform_now(payload: status_payload(wamid: msg.wamid, status: "sent"))

    assert_equal "read", msg.reload.status
  end

  test "ignores unknown wamid in status event" do
    assert_nothing_raised do
      Whatsapp::ProcessWebhookJob.perform_now(payload: status_payload(wamid: "wamid.UNKNOWN", status: "sent"))
    end
  end

  test "duplicate status event is idempotent" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :sent)
    payload = status_payload(wamid: msg.wamid, status: "delivered")

    Whatsapp::ProcessWebhookJob.perform_now(payload: payload)
    Whatsapp::ProcessWebhookJob.perform_now(payload: payload)

    assert_equal "delivered", msg.reload.status
  end

  # ── Inbound messages ────────────────────────────────────────────────────────

  test "creates inbound whatsapp message for known conversation" do
    conversation = whatsapp_conversations(:one)

    assert_difference "WhatsappMessage.count", 1 do
      Whatsapp::ProcessWebhookJob.perform_now(payload: inbound_payload(wamid: "wamid.NEWMSG1"))
    end

    msg = WhatsappMessage.last
    assert_equal "wamid.NEWMSG1", msg.wamid
    assert msg.inbound?
    assert_equal "Hello!", msg.body
    assert_equal "text", msg.message_type
    assert_equal "delivered", msg.status
  end

  test "updates conversation state after inbound message" do
    conversation = whatsapp_conversations(:one)
    conversation.update!(unread: false)

    Whatsapp::ProcessWebhookJob.perform_now(payload: inbound_payload(wamid: "wamid.NEWMSG2"))

    conversation.reload
    assert conversation.unread
    assert_in_delta Time.current.to_i, conversation.last_message_at.to_i, 5
    assert_in_delta 24.hours.from_now.to_i, conversation.session_expires_at.to_i, 5
  end

  test "updates customer name from contact profile" do
    conversation = whatsapp_conversations(:one)

    Whatsapp::ProcessWebhookJob.perform_now(
      payload: inbound_payload(wamid: "wamid.NEWMSG3", name: "Maria Santos")
    )

    assert_equal "Maria Santos", conversation.reload.customer_name
  end

  test "duplicate wamid is skipped (idempotent)" do
    existing = whatsapp_messages(:inbound_reply)

    assert_no_difference "WhatsappMessage.count" do
      Whatsapp::ProcessWebhookJob.perform_now(
        payload: inbound_payload(wamid: existing.wamid)
      )
    end
  end

  test "inbound message from unknown wa_id is logged and skipped" do
    assert_no_difference "WhatsappMessage.count" do
      Whatsapp::ProcessWebhookJob.perform_now(
        payload: inbound_payload(wamid: "wamid.NEWMSG4", wa_id: "5511000000000")
      )
    end
  end

  # ── Notifications ───────────────────────────────────────────────────────────

  test "creates notification for space owner on inbound message" do
    space = spaces(:one)
    owner = space.owner

    Whatsapp::ProcessWebhookJob.perform_now(payload: inbound_payload(wamid: "wamid.NOTIF1"))

    owner_notif = Notification.where(event_type: "whatsapp_message_received")
                               .find_by(user: owner)
    assert_not_nil owner_notif
    assert_equal whatsapp_conversations(:one), owner_notif.notifiable
  end

  test "creates notification for each space member on inbound message" do
    space      = spaces(:one)
    member_ids = space.space_memberships.pluck(:user_id)
    all_ids    = (member_ids + [ space.owner_id ]).compact.uniq

    assert_difference "Notification.count", all_ids.size do
      Whatsapp::ProcessWebhookJob.perform_now(payload: inbound_payload(wamid: "wamid.NOTIF2"))
    end
  end

  test "notification body uses customer phone when name is absent" do
    conversation = whatsapp_conversations(:one)
    conversation.update!(customer_name: nil)

    Whatsapp::ProcessWebhookJob.perform_now(
      payload: inbound_payload(wamid: "wamid.NOTIF3", name: nil)
    )

    notif = Notification.where(event_type: "whatsapp_message_received").last
    assert_includes notif.body, conversation.customer_phone
  end

  # ── Notification target_path ─────────────────────────────────────────────

  test "notification target_path routes to inbox show" do
    conversation = whatsapp_conversations(:one)
    notif = Notification.new(notifiable: conversation, notifiable_type: "WhatsappConversation",
                             notifiable_id: conversation.id)

    path = notif.target_path
    assert_equal "spaces/inbox", path[:controller]
    assert_equal "show", path[:action]
    assert_equal conversation.id, path[:id]
  end

  # ── Credit refund on failure ────────────────────────────────────────────────

  test "credit refund failure is logged but does not raise" do
    msg = whatsapp_messages(:outbound_template)
    msg.update!(status: :sent)

    raising_manager = Object.new
    def raising_manager.refund(**) = raise(StandardError, "Asaas error")

    Billing::CreditManager.stub(:new, raising_manager) do
      assert_nothing_raised do
        Whatsapp::ProcessWebhookJob.perform_now(payload: status_payload(wamid: msg.wamid, status: "failed"))
      end
    end
  end

  # ── Malformed payload ────────────────────────────────────────────────────────

  test "malformed JSON payload is discarded without error" do
    assert_nothing_raised do
      Whatsapp::ProcessWebhookJob.perform_now(payload: "not json {{{")
    end
  end
end
