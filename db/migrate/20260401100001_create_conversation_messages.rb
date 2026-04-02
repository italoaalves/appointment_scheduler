# frozen_string_literal: true

class CreateConversationMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :direction, null: false
      t.text :body
      t.string :message_type, default: "text"
      t.integer :status, default: 0
      t.string :external_message_id
      t.references :sent_by, foreign_key: { to_table: :users }, index: false
      t.integer :credit_cost, default: 0, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :conversation_messages, [ :conversation_id, :created_at ]
    add_index :conversation_messages, :external_message_id, unique: true,
              where: "external_message_id IS NOT NULL"
    add_index :conversation_messages, :sent_by_id
  end
end
