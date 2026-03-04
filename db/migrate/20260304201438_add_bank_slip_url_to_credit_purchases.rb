class AddBankSlipUrlToCreditPurchases < ActiveRecord::Migration[8.0]
  def change
    add_column :credit_purchases, :bank_slip_url, :string
  end
end
