# frozen_string_literal: true

class CreateBillingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :billing_events do |t|
      t.references :space,        null: false, foreign_key: true
      t.references :subscription, null: true,  foreign_key: true
      t.string  :event_type, null: false
      t.jsonb   :metadata,   null: false, default: {}
      t.integer :actor_id

      # Append-only — no updated_at
      t.datetime :created_at, null: false
    end

    add_index :billing_events, [ :space_id, :created_at ],
              name: "index_billing_events_on_space_id_and_created_at"

    add_index :billing_events, :event_type,
              name: "index_billing_events_on_event_type"
  end
end
