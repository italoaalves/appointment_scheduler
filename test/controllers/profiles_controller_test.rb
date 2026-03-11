# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # spaces(:one) has a trialing subscription; spaces(:two) has an active subscription.
    @trialing_user = users(:manager)
    @active_user   = users(:manager_two)
  end

  # --- Phone update blocked during trial ---

  test "trialing user cannot change phone number via profile form" do
    @trialing_user.update_column(:phone_number, "+5511999990100")
    sign_in @trialing_user

    patch profile_path, params: {
      user: { phone_number: "+5511999990101" }
    }

    # Controller strips the field → phone stays unchanged
    assert_equal "+5511999990100", @trialing_user.reload.phone_number
  end

  test "trialing user can still update name during trial" do
    sign_in @trialing_user

    patch profile_path, params: {
      user: { name: "New Name" }
    }

    assert_redirected_to edit_profile_path
    assert_equal "New Name", @trialing_user.reload.name
  end

  # --- Phone update allowed on active plan ---

  test "active subscriber can change phone number via profile form" do
    @active_user.update_column(:phone_number, "+5511999990200")
    sign_in @active_user

    patch profile_path, params: {
      user: { phone_number: "+5511999990201" }
    }

    assert_redirected_to edit_profile_path
    assert_equal "+5511999990201", @active_user.reload.phone_number
  end

  # --- Profile page shows read-only field for trialing users ---

  test "profile edit shows phone field as disabled for trialing user" do
    sign_in @trialing_user
    get edit_profile_path

    assert_response :success
    assert_select "input[name='user[phone_number]'][disabled]"
  end

  test "profile edit shows phone field as enabled for active user" do
    sign_in @active_user
    get edit_profile_path

    assert_response :success
    assert_select "input[name='user[phone_number]']:not([disabled])"
  end
end
