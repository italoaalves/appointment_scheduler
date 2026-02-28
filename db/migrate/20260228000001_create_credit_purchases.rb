# frozen_string_literal: true

class CreateCreditPurchases < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_purchases do |t|
      t.references :space,         null: false, foreign_key: true
      t.references :credit_bundle, null: false, foreign_key: { to_table: :credit_bundles }
      t.integer    :amount,        null: false
      t.integer    :price_cents,   null: false
      t.integer    :status,        null: false, default: 0
      t.integer    :actor_id
      t.string     :asaas_payment_id
      t.string     :invoice_url
      t.timestamps
    end

    add_index :credit_purchases, :asaas_payment_id, unique: true, where: "asaas_payment_id IS NOT NULL"
    add_index :credit_purchases, [ :space_id, :status ]
  end
end
