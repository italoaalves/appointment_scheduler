# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :space, null: false, foreign_key: true
      t.string  :plan_id,                null: false
      t.integer :status,                 null: false, default: 0
      t.string  :asaas_subscription_id
      t.string  :asaas_customer_id
      t.integer :payment_method
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :trial_ends_at
      t.datetime :canceled_at

      t.timestamps
    end

    # One non-expired subscription per space (status 4 = expired)
    add_index :subscriptions, :space_id,
              unique: true,
              where: "status NOT IN (4)",
              name: "index_subscriptions_on_space_id_active"

    add_index :subscriptions, :asaas_subscription_id,
              unique: true,
              where: "asaas_subscription_id IS NOT NULL",
              name: "index_subscriptions_on_asaas_subscription_id"

    add_index :subscriptions, [ :status, :trial_ends_at ],
              name: "index_subscriptions_on_status_and_trial_ends_at"
  end
end
