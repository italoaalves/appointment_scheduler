require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to sign in" do
    get dashboard_url
    assert_response :redirect
    assert_redirected_to new_user_session_url
  end

  test "signed in user gets dashboard" do
    sign_in users(:manager)
    get dashboard_url
    assert_response :success
  end
end
