class AddConfirmationStateToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :confirmation_state, :integer, null: false, default: 0
    add_column :appointments, :confirmation_decided_at, :datetime
    add_column :appointments, :confirmation_decided_via, :string

    add_index :appointments, [ :space_id, :confirmation_state ]
  end
end
