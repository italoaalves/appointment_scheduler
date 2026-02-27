# frozen_string_literal: true

class CreateBillingPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :billing_plans do |t|
      t.string  :slug,                     null: false
      t.string  :name,                     null: false
      t.text    :description
      t.integer :price_cents,              null: false, default: 0
      t.integer :max_team_members                       # nil = unlimited
      t.integer :max_customers                          # nil = unlimited
      t.integer :max_scheduling_links                   # nil = unlimited
      t.integer :whatsapp_monthly_quota                 # nil = unlimited, 0 = none
      t.jsonb   :features,                null: false, default: []
      t.jsonb   :allowed_payment_methods, null: false, default: []
      t.integer :position,                null: false, default: 0
      t.boolean :public,                  null: false, default: true
      t.boolean :highlighted,             null: false, default: false
      t.boolean :trial_default,           null: false, default: false
      t.boolean :active,                  null: false, default: true

      t.timestamps
    end

    add_index :billing_plans, :slug,          unique: true
    add_index :billing_plans, :position
    add_index :billing_plans, :trial_default, unique: true, where: "trial_default = TRUE"
  end
end
