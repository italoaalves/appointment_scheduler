# frozen_string_literal: true

class CreateMessageCredits < ActiveRecord::Migration[8.0]
  def change
    create_table :message_credits do |t|
      t.references :space, null: false, foreign_key: true
      t.integer :balance,                 null: false, default: 0
      t.integer :monthly_quota_remaining, null: false, default: 0
      t.datetime :quota_refreshed_at

      t.timestamps
    end

    add_index :message_credits, :space_id,
              unique: true,
              name: "index_message_credits_on_space_id_unique"
  end
end
