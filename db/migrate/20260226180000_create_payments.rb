# frozen_string_literal: true

class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :subscription, null: false, foreign_key: true
      t.references :space,        null: false, foreign_key: true
      t.string  :asaas_payment_id, null: false
      t.integer :amount_cents,     null: false
      t.integer :payment_method,   null: false
      t.integer :status,           null: false, default: 0
      t.datetime :paid_at

      t.timestamps
    end

    add_index :payments, :asaas_payment_id,
              unique: true,
              name: "index_payments_on_asaas_payment_id"

    add_index :payments, [ :subscription_id, :created_at ],
              name: "index_payments_on_subscription_id_and_created_at"
  end
end
