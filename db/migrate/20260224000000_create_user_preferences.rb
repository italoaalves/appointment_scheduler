# frozen_string_literal: true

class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :locale, default: "pt-BR", null: false

      t.timestamps
    end
  end
end
