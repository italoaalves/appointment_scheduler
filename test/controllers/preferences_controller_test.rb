# frozen_string_literal: true

require "test_helper"

class PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:manager)
  end

  test "signed in user can view preferences inside the account settings shell" do
    sign_in @user

    get edit_preferences_path

    assert_response :success
    assert_select "[data-role='settings-shell']"
    assert_select "a[href='#{edit_profile_path}']", text: I18n.t("account.sidebar.profile"), minimum: 1
    assert_select "a[href='#{profile_security_path}']", text: I18n.t("account.sidebar.security"), minimum: 1
    assert_select "h1", text: I18n.t("preferences.edit.title")
    assert_select "form[action='#{preferences_path}']"
  end
end
