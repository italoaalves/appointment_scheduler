# frozen_string_literal: true

class SyncUserPermissions
  def self.call(user, permission_names)
    new(user, permission_names).call
  end

  def initialize(user, permission_names)
    @user = user
    @desired = Array(permission_names).reject(&:blank?).map(&:to_s) & PermissionService::ALLOWED_PERMISSIONS
  end

  def call
    current = @user.permission_names
    (current - @desired).each { |p| @user.user_permissions.find_by(permission: p)&.destroy }
    (@desired - current).each { |p| @user.user_permissions.find_or_create_by!(permission: p) }
    @user.clear_permission_cache!
  end
end
