class CreateWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_messages do |t|
      t.references :whatsapp_conversation, null: false, foreign_key: true
      t.string :wamid
      t.integer :direction, null: false
      t.text :body
      t.string :message_type, default: "text", null: false
      t.integer :status, default: 0, null: false
      t.references :sent_by, foreign_key: { to_table: :users }
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :whatsapp_messages, :wamid, unique: true, where: "wamid IS NOT NULL"
  end
end
