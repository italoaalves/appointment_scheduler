# frozen_string_literal: true

class IntroduceSpaceMemberships < ActiveRecord::Migration[8.0]
  def up
    create_table :space_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :space, null: false, foreign_key: true
      t.timestamps
    end

    add_index :space_memberships, [ :user_id, :space_id ], unique: true

    execute <<~SQL
      INSERT INTO space_memberships (user_id, space_id, created_at, updated_at)
      SELECT id, space_id, NOW(), NOW()
      FROM users
      WHERE space_id IS NOT NULL
    SQL

    remove_foreign_key :users, :spaces
    remove_column :users, :space_id
  end

  def down
    add_reference :users, :space, foreign_key: true

    execute <<~SQL
      UPDATE users
      SET space_id = sm.space_id
      FROM space_memberships sm
      WHERE users.id = sm.user_id
    SQL

    drop_table :space_memberships
  end
end
