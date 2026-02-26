# frozen_string_literal: true

# Permission-based authorization (Option 2 naming).
#
# Design: Service Object + Model Delegate
# - PermissionService: stateless, single source of truth for permission checks
# - User#can?: delegates to PermissionService for clean `current_user.can?(:manage_space)`
# - RequirePermission concern: provides `require_permission :permission` class macro for controllers
class PermissionService
  ALLOWED_PERMISSIONS = %w[
    access_space_dashboard manage_space manage_team manage_customers
    manage_appointments destroy_appointments manage_scheduling_links
    manage_personalized_links manage_policies own_space
  ].freeze

  def self.can?(user:, permission:, space: nil)
    new(user: user, space: space).can?(permission)
  end

  def initialize(user:, space: nil)
    @user = user
    @space = space
  end

  def can?(permission)
    return false unless @user.present?
    return true if @user.super_admin?
    return false unless ALLOWED_PERMISSIONS.include?(permission.to_s)
    return false unless @space.nil? || @user.space&.id == @space&.id

    # Space owner has full access by default
    return true if @space.present? && @user.space_owner?(@space)

    @user.permission_names.include?(permission.to_s)
  end

  private

  attr_reader :user, :space
end
