# frozen_string_literal: true

require "test_helper"

module Inbox
  class CheckSlaBreachesJobTest < ActiveSupport::TestCase
    setup do
      @space = spaces(:one)
      @job   = CheckSlaBreachesJob.new
    end

    # Create a conversation that is breachable: needs_reply, past deadline, no response.
    def breachable_conversation(overrides = {})
      Conversation.create!({
        space: @space,
        channel: :whatsapp,
        status: :needs_reply,
        priority: :normal,
        external_id: "breach_test_#{SecureRandom.hex(4)}",
        contact_identifier: "+5511900000000",
        contact_name: "Test User",
        sla_deadline_at: 1.minute.ago,
        sla_breached: false,
        first_response_at: nil
      }.merge(overrides))
    end

    test "marks overdue conversations as sla_breached" do
      conv = breachable_conversation
      @job.perform
      assert conv.reload.sla_breached
    end

    test "creates notifications for space members when no assignee" do
      conv = breachable_conversation
      member_count = (@space.space_memberships.pluck(:user_id) + [ @space.owner_id ]).compact.uniq.size

      assert_difference "Notification.count", member_count do
        @job.perform
      end
    end

    test "creates notification only for assignee when conversation is assigned" do
      assignee = users(:manager)
      conv = breachable_conversation(assigned_to: assignee)

      assert_difference "Notification.count", 1 do
        @job.perform
      end

      notification = Notification.order(:created_at).last
      assert_equal assignee.id, notification.user_id
      assert_equal "sla_breach", notification.event_type
    end

    test "is idempotent: already-breached conversations are not re-notified" do
      conv = breachable_conversation(sla_breached: true)

      assert_no_difference "Notification.count" do
        @job.perform
      end
    end

    test "skips resolved conversations" do
      conv = breachable_conversation(status: :resolved)

      @job.perform
      assert_not conv.reload.sla_breached
    end

    test "skips closed conversations" do
      conv = breachable_conversation(status: :closed)

      @job.perform
      assert_not conv.reload.sla_breached
    end

    test "skips conversations with a future deadline" do
      conv = breachable_conversation(sla_deadline_at: 1.hour.from_now)

      @job.perform
      assert_not conv.reload.sla_breached
    end

    test "skips conversations that already have a first response" do
      conv = breachable_conversation(first_response_at: 5.minutes.ago)

      @job.perform
      assert_not conv.reload.sla_breached
    end

    test "skips conversations with no sla_deadline_at" do
      # Create the record first, then clear sla_deadline_at with update_column
      # to bypass the after_save callback that would auto-set it.
      conv = breachable_conversation
      conv.update_column(:sla_deadline_at, nil)

      @job.perform
      assert_not conv.reload.sla_breached
    end

    test "notification body includes contact name" do
      conv = breachable_conversation(contact_name: "João Silva")
      @job.perform

      notification = Notification.order(:created_at).last
      assert_includes notification.body, "João Silva"
    end

    test "notification body falls back to contact_identifier when name is blank" do
      conv = breachable_conversation(contact_name: nil, contact_identifier: "+5511999991234")
      @job.perform

      notification = Notification.order(:created_at).last
      assert_includes notification.body, "+5511999991234"
    end
  end
end
