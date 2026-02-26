# frozen_string_literal: true

require "test_helper"

class PermissionServiceTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @manager = users(:manager)
    @secretary = users(:secretary)
    @admin = users(:admin)
    @other_manager = users(:manager_two)
  end

  test "returns false for nil user" do
    assert_not PermissionService.can?(user: nil, permission: :manage_space, space: @space)
  end

  test "super_admin can do anything" do
    assert PermissionService.can?(user: @admin, permission: :manage_space, space: @space)
    assert PermissionService.can?(user: @admin, permission: :destroy_appointments, space: @space)
  end

  test "space owner has full access to own space" do
    @space.update!(owner_id: @manager.id)
    assert PermissionService.can?(user: @manager, permission: :manage_space, space: @space)
    assert PermissionService.can?(user: @manager, permission: :manage_team, space: @space)
    assert PermissionService.can?(user: @manager, permission: :destroy_appointments, space: @space)
  end

  test "user with explicit permission can perform action" do
    assert PermissionService.can?(user: @secretary, permission: :access_space_dashboard, space: @space)
    assert PermissionService.can?(user: @secretary, permission: :manage_customers, space: @space)
  end

  test "user without permission is denied" do
    assert_not PermissionService.can?(user: @secretary, permission: :manage_team, space: @space)
    assert_not PermissionService.can?(user: @secretary, permission: :manage_space, space: @space)
  end

  test "user cannot access another space" do
    other_space = spaces(:two)
    assert_not PermissionService.can?(user: @secretary, permission: :manage_customers, space: other_space)
  end

  test "rejects unknown permissions" do
    assert_not PermissionService.can?(user: @manager, permission: :nonexistent_permission, space: @space)
  end

  test "works with string permissions" do
    assert PermissionService.can?(user: @secretary, permission: "manage_customers", space: @space)
  end

  test "works without space argument for super_admin" do
    assert PermissionService.can?(user: @admin, permission: :manage_space)
  end

  test "user in space one cannot act on space two" do
    space_two = spaces(:two)
    assert_not PermissionService.can?(user: @manager, permission: :manage_space, space: space_two)
  end
end
