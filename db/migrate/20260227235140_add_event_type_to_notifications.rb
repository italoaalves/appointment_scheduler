class AddEventTypeToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :event_type, :string, null: false, default: ""
    add_index :notifications, :event_type
  end
end
