# frozen_string_literal: true

class GrantInboxPermissionsToOwners < ActiveRecord::Migration[8.0]
  INBOX_PERMISSIONS = %w[read_inbox write_inbox].freeze

  def up
    owners = User.unscoped
                 .joins("INNER JOIN spaces ON spaces.owner_id = users.id")
                 .select("DISTINCT users.id")

    now = Time.current

    owners.each do |owner|
      INBOX_PERMISSIONS.each do |perm|
        next if UserPermission.exists?(user_id: owner.id, permission: perm)

        execute <<~SQL.squish
          INSERT INTO user_permissions (user_id, permission, created_at, updated_at)
          VALUES (#{owner.id}, #{connection.quote(perm)}, #{connection.quote(now)}, #{connection.quote(now)})
        SQL
      end
    end
  end

  def down
    execute <<~SQL.squish
      DELETE FROM user_permissions WHERE permission IN ('read_inbox', 'write_inbox')
    SQL
  end
end
