# frozen_string_literal: true

require "test_helper"

class Whatsapp::NotifySpaceMembersJobTest < ActiveJob::TestCase
  test "creates notifications for all space members and owner" do
    conversation = whatsapp_conversations(:one)
    space        = conversation.space
    member_ids   = space.space_memberships.pluck(:user_id)
    all_ids      = (member_ids + [ space.owner_id ]).compact.uniq

    assert_difference "Notification.count", all_ids.size do
      Whatsapp::NotifySpaceMembersJob.perform_now(conversation_id: conversation.id)
    end

    all_ids.each do |user_id|
      notif = Notification.find_by(user_id: user_id, notifiable: conversation, event_type: "whatsapp_message_received")
      assert_not_nil notif, "Expected notification for user #{user_id}"
    end
  end

  test "notification body uses customer name when present" do
    conversation = whatsapp_conversations(:one)

    Whatsapp::NotifySpaceMembersJob.perform_now(conversation_id: conversation.id)

    notif = Notification.find_by(event_type: "whatsapp_message_received")
    assert_includes notif.body, conversation.customer_name
  end

  test "notification body uses customer phone when name is absent" do
    conversation = whatsapp_conversations(:one)
    conversation.update!(customer_name: nil)

    Whatsapp::NotifySpaceMembersJob.perform_now(conversation_id: conversation.id)

    notif = Notification.find_by(event_type: "whatsapp_message_received")
    assert_includes notif.body, conversation.customer_phone
  end

  test "silently skips when conversation does not exist" do
    assert_nothing_raised do
      Whatsapp::NotifySpaceMembersJob.perform_now(conversation_id: -1)
    end
  end

  test "duplicate execution creates additional notifications (insert_all does not deduplicate)" do
    conversation = whatsapp_conversations(:one)
    space        = conversation.space
    member_ids   = space.space_memberships.pluck(:user_id)
    all_ids      = (member_ids + [ space.owner_id ]).compact.uniq

    Whatsapp::NotifySpaceMembersJob.perform_now(conversation_id: conversation.id)

    # Second run — insert_all doesn't check for duplicates, so count doubles
    assert_difference "Notification.count", all_ids.size do
      Whatsapp::NotifySpaceMembersJob.perform_now(conversation_id: conversation.id)
    end
  end
end
