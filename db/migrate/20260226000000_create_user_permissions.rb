# frozen_string_literal: true

class CreateUserPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :permission, null: false

      t.timestamps
    end

    add_index :user_permissions, [ :user_id, :permission ], unique: true
  end
end
