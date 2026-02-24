# frozen_string_literal: true

class CreatePersonalizedSchedulingLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :personalized_scheduling_links do |t|
      t.references :space, null: false, foreign_key: true
      t.string :slug, null: false

      t.timestamps
    end

    add_index :personalized_scheduling_links, :slug, unique: true
  end
end
