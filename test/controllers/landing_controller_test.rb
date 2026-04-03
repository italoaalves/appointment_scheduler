require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  test "GET / unauthenticated returns 200" do
    get root_path
    assert_response :success
  end

  test "GET / unauthenticated renders landing layout" do
    get root_path
    assert_select "h1", text: /Continuous connection/
  end

  test "GET / unauthenticated includes trial CTA" do
    get root_path
    assert_select "a", text: /14-Day Trial/
  end

  test "GET / unauthenticated shows plans from DB" do
    get root_path
    Billing::Plan.visible.ordered.each do |plan|
      assert_select "h3", text: plan.name
    end
  end

  test "GET / authenticated redirects to dashboard" do
    user = users(:manager)
    sign_in user
    get root_path
    assert_redirected_to dashboard_path
  end

  test "GET /dashboard authenticated returns 200" do
    user = users(:manager)
    sign_in user
    get dashboard_path
    assert_response :success
  end
end
