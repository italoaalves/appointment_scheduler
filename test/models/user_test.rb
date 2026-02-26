# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @space = spaces(:one)
    @manager = users(:manager)
    @secretary = users(:secretary)
    @admin = users(:admin)
  end

  test "can? delegates to PermissionService" do
    assert @manager.can?(:manage_space, space: @space)
    assert_not @secretary.can?(:manage_space, space: @space)
  end

  test "space_owner? returns true for owner" do
    @space.update!(owner_id: @manager.id)
    assert @manager.space_owner?(@space)
  end

  test "space_owner? returns false for non-owner" do
    @space.update!(owner_id: @manager.id)
    assert_not @secretary.space_owner?(@space)
  end

  test "permission_names returns list of permissions" do
    names = @secretary.permission_names
    assert_includes names, "access_space_dashboard"
    assert_includes names, "manage_customers"
    assert_not_includes names, "manage_team"
  end

  test "permission_names is memoized" do
    names1 = @secretary.permission_names
    names2 = @secretary.permission_names
    assert_same names1, names2
  end

  test "clear_permission_cache! resets memoization" do
    first_call = @secretary.permission_names
    @secretary.clear_permission_cache!
    second_call = @secretary.permission_names
    assert_not_same first_call, second_call
    assert_equal first_call, second_call
  end

  test "sync_permissions_from_param via service" do
    @secretary.permission_names_param = %w[access_space_dashboard manage_team]
    @secretary.save!

    @secretary.reload
    assert_includes @secretary.permission_names, "manage_team"
    assert_not_includes @secretary.permission_names, "manage_customers"
  end

  test "ensures user_preference on create" do
    user = User.create!(
      email: "pref_test@example.com",
      password: "password123",
      space: @space
    )
    assert_not_nil user.user_preference
    assert_equal I18n.default_locale.to_s, user.user_preference.locale
  end
end
