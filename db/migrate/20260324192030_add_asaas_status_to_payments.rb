class AddAsaasStatusToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :asaas_status, :string
  end
end
