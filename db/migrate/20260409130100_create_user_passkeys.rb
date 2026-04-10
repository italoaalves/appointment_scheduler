# frozen_string_literal: true

class CreateUserPasskeys < ActiveRecord::Migration[8.1]
  def change
    create_table :user_passkeys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :label, null: false
      t.jsonb :transports, null: false, default: []
      t.boolean :platform_authenticator, null: false, default: false
      t.boolean :backup_eligible
      t.boolean :backup_state
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :user_passkeys, :external_id, unique: true
  end
end
