class AddNormalizedPhoneToWhatsappPhoneNumbers < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_phone_numbers, :normalized_phone, :string
    add_index :whatsapp_phone_numbers, :normalized_phone

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE whatsapp_phone_numbers
          SET normalized_phone = REGEXP_REPLACE(display_number, '[^0-9]', '', 'g')
        SQL
      end
    end
  end
end
