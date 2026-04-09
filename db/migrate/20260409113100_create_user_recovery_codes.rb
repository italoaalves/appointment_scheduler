# frozen_string_literal: true

class CreateUserRecoveryCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :user_recovery_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :user_recovery_codes, [ :user_id, :used_at ]
  end
end
