# frozen_string_literal: true

class AddPixFieldsToCreditPurchases < ActiveRecord::Migration[8.0]
  def change
    add_column :credit_purchases, :pix_qr_code_base64, :text
    add_column :credit_purchases, :pix_payload, :text
  end
end
