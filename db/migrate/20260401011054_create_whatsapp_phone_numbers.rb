# frozen_string_literal: true

class CreateWhatsappPhoneNumbers < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_phone_numbers do |t|
      t.references :space, foreign_key: true, null: true, index: false  # nil = system bot; custom partial index below
      t.string :phone_number_id, null: false               # Meta's phone number ID
      t.string :display_number, null: false                 # Human-readable "+55 11 99999-0000"
      t.string :waba_id, null: false                        # WhatsApp Business Account ID
      t.string :verified_name                               # Business name shown to customers
      t.string :quality_rating                              # GREEN, YELLOW, RED
      t.integer :status, default: 0, null: false            # enum

      t.timestamps
      t.index :phone_number_id, unique: true
      t.index :space_id, unique: true, where: "space_id IS NOT NULL"
    end
  end
end
