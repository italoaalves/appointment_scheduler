class CreateWhatsappConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_conversations do |t|
      t.references :space, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :wa_id, null: false
      t.string :customer_name
      t.string :customer_phone, null: false
      t.datetime :last_message_at
      t.datetime :session_expires_at
      t.boolean :unread, default: false, null: false

      t.timestamps
    end

    add_index :whatsapp_conversations, [ :space_id, :wa_id ], unique: true
  end
end
