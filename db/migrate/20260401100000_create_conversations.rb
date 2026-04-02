# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :space, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.integer :channel, null: false
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 1
      t.string :subject
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :external_id, null: false
      t.string :contact_identifier, null: false
      t.string :contact_name
      t.datetime :session_expires_at
      t.datetime :last_message_at
      t.datetime :first_response_at
      t.boolean :unread, default: false, null: false
      t.jsonb :metadata, default: {}
      t.datetime :sla_deadline_at
      t.string :last_message_body
      t.integer :credit_cost_total, default: 0, null: false
      t.boolean :sla_breached, default: false, null: false

      t.timestamps
    end

    add_index :conversations, [ :space_id, :channel, :external_id ], unique: true
    add_index :conversations, [ :space_id, :status, :last_message_at ]
    add_index :conversations, [ :space_id, :assigned_to_id ],
              where: "assigned_to_id IS NOT NULL"
    add_index :conversations, [ :space_id, :customer_id ]
    add_index :conversations, [ :space_id, :sla_breached ],
              where: "sla_breached = true"
    add_index :conversations, [ :space_id, :channel ]
    add_index :conversations, [ :space_id, :unread ],
              where: "unread = true AND status IN (1, 2, 3)"
  end
end
