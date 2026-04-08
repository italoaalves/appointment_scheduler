class AddWhatsappConsentToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :whatsapp_opted_in_at, :datetime
    add_column :customers, :whatsapp_opt_in_source, :string
    add_column :customers, :whatsapp_opted_out_at, :datetime
    add_column :customers, :whatsapp_opt_out_source, :string
  end
end
