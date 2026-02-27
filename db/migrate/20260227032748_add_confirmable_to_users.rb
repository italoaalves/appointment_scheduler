class AddConfirmableToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    add_index :users, :confirmation_token, unique: true

    # Mark existing users as confirmed so they can still sign in
    User.reset_column_information
    User.update_all(confirmed_at: Time.current)
  end

  def down
    remove_index :users, :confirmation_token, if_exists: true
    remove_column :users, :confirmation_token
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_sent_at
    remove_column :users, :unconfirmed_email
  end
end
