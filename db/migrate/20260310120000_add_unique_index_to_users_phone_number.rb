class AddUniqueIndexToUsersPhoneNumber < ActiveRecord::Migration[8.0]
  def up
    # Nullify duplicate phone numbers before adding the unique index.
    # For each duplicated phone, keep only the row with the smallest id.
    execute <<~SQL
      UPDATE users
      SET phone_number = NULL
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM users
        WHERE phone_number IS NOT NULL
        GROUP BY phone_number
      )
      AND phone_number IS NOT NULL
    SQL

    add_index :users, :phone_number, unique: true
  end

  def down
    remove_index :users, :phone_number
  end
end
