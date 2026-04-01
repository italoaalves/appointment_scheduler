# frozen_string_literal: true

class AddMetadataToWhatsappPhoneNumbers < ActiveRecord::Migration[8.0]
  def change
    add_column :whatsapp_phone_numbers, :metadata, :jsonb, default: {}, null: false
  end
end
