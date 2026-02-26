# frozen_string_literal: true

class AddMissingIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :notifications, [ :user_id, :read ], name: "index_notifications_on_user_id_and_read"
    add_index :messages, [ :recipient_id, :created_at ], name: "index_messages_on_recipient_id_created_at"
    add_index :messages, [ :sender_id, :created_at ], name: "index_messages_on_sender_id_created_at"
  end
end
