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
      phone_number: "+5511999990001",
      space: @space
    )
    assert_not_nil user.user_preference
    assert_equal I18n.default_locale.to_s, user.user_preference.locale
  end

  # --- Phone number validation ---

  test "requires phone_number when require_phone_number flag is set" do
    user = User.new(email: "no_phone@example.com", password: "password123", space: @space,
                    require_phone_number: true)
    assert_not user.valid?
    assert user.errors[:phone_number].any?
  end

  test "does not require phone_number for admin-created users" do
    user = User.new(email: "admin_created@example.com", password: "password123", space: @space)
    user.valid?
    assert_empty user.errors[:phone_number]
  end

  test "phone_number uniqueness rejects duplicate with generic error on phone_number attribute" do
    User.create!(
      email: "first@example.com",
      password: "password123",
      phone_number: "+5511988880001",
      space: @space
    )

    duplicate = User.new(
      email: "second@example.com",
      password: "password123",
      phone_number: "+5511988880001",
      space: @space
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:phone_number].any?
    # Generic message does not reveal that the phone is already registered
    assert_not_includes duplicate.errors[:phone_number], I18n.t("errors.messages.taken")
  end

  test "normalizes phone number by stripping non-digits and prepending +" do
    user = User.new(
      email: "norm@example.com",
      password: "password123",
      phone_number: "(11) 99999-9999",
      space: @space
    )
    user.valid?
    # (11) 99999-9999 → digits: 11999999999 → +11999999999
    assert_equal "+11999999999", user.phone_number
  end

  test "different formats of same number are normalized to identical value" do
    user1 = User.new(phone_number: "+5511999990002")
    user1.valid?

    user2 = User.new(phone_number: "5511999990002")
    user2.valid?

    user3 = User.new(phone_number: "(55) 11 99999-0002")
    user3.valid?

    assert_equal user1.phone_number, user2.phone_number
    assert_equal user1.phone_number, user3.phone_number
  end

  test "blank phone_number is normalized to nil" do
    user = User.new(phone_number: "   ")
    user.valid?
    assert_nil user.phone_number
  end

  test "existing user without phone_number can be saved without phone presence error" do
    # Fixtures load via SQL bypassing model validations (no phone_number).
    # Ensure they can still be saved — the flag is not set for non-registration paths.
    @manager.name = "Updated Name"
    assert @manager.save
    assert_empty @manager.errors[:phone_number]
  end

  # --- Phone lock during trial ---

  test "trialing user cannot change phone number" do
    # spaces(:one) has a trialing subscription
    @manager.update_column(:phone_number, "+5511999990010")
    @manager.reload
    @manager.phone_number = "+5511999990011"

    assert_not @manager.valid?
    assert_includes @manager.errors[:phone_number],
                    I18n.t("activerecord.errors.models.user.attributes.phone_number.locked_during_trial")
  end

  test "active subscriber can change phone number" do
    # spaces(:two) has an active subscription
    manager_two = users(:manager_two)
    manager_two.update_column(:phone_number, "+5511999990020")
    manager_two.reload
    manager_two.phone_number = "+5511999990021"

    assert manager_two.valid?
    assert_empty manager_two.errors[:phone_number]
  end

  test "super_admin is exempt from phone lock during trial" do
    # @admin is a super_admin with no space
    @admin.update_column(:phone_number, "+5511999990030")
    @admin.reload
    @admin.phone_number = "+5511999990031"

    assert @admin.valid?
    assert_empty @admin.errors[:phone_number]
  end

  test "phone lock does not fire when phone number is unchanged" do
    @manager.update_column(:phone_number, "+5511999990040")
    @manager.reload
    @manager.name = "Changed Name Only"

    assert @manager.valid?
    assert_empty @manager.errors[:phone_number]
  end
end
