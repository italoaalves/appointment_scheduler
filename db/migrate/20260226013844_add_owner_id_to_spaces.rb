class AddOwnerIdToSpaces < ActiveRecord::Migration[8.0]
  def change
    add_reference :spaces, :owner, foreign_key: { to_table: :users }

    reversible do |dir|
      dir.up do
        # Backfill: set owner to first user with own_space permission in each space
        execute <<-SQL.squish
          UPDATE spaces s
          SET owner_id = (
            SELECT u.id
            FROM users u
            INNER JOIN user_permissions up ON up.user_id = u.id AND up.permission = 'own_space'
            WHERE u.space_id = s.id
            LIMIT 1
          )
          WHERE s.owner_id IS NULL
        SQL
      end
    end
  end
end
