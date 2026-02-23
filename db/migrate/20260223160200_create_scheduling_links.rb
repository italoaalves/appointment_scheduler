# frozen_string_literal: true

class CreateSchedulingLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduling_links do |t|
      t.references :space, null: false, foreign_key: true
      t.string :token, null: false, index: { unique: true }
      t.integer :link_type, default: 0, null: false
      t.datetime :expires_at
      t.datetime :used_at
      t.string :name

      t.timestamps
    end
  end
end
