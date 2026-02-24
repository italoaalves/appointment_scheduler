# frozen_string_literal: true

require "test_helper"

module Admin
  class SpaceControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @space = @manager.space
    end

    test "redirects unauthenticated to login" do
      get edit_admin_space_url
      assert_redirected_to new_user_session_url
    end

    test "manager can edit space" do
      sign_in @manager
      get edit_admin_space_url
      assert_response :success
      assert_select "h1", text: /Space settings|Configurações do espaço/
    end

    test "secretary cannot edit space" do
      sign_in @secretary
      get edit_admin_space_url
      assert_redirected_to root_url
    end

    test "manager can update space" do
      sign_in @manager
      patch admin_space_url, params: {
        space: {
          name: "Updated Space",
          business_type: "Dental clinic",
          address: "123 Main St",
          phone: "+5511999999999",
          email: "contact@space.com",
          instagram_url: "https://instagram.com/space",
          facebook_url: "https://facebook.com/space"
        }
      }
      assert_redirected_to edit_admin_space_url
      @space.reload
      assert_equal "Updated Space", @space.name
      assert_equal "Dental clinic", @space.business_type
      assert_equal "123 Main St", @space.address
      assert_equal "+5511999999999", @space.phone
      assert_equal "contact@space.com", @space.email
      assert_equal "https://instagram.com/space", @space.instagram_url
      assert_equal "https://facebook.com/space", @space.facebook_url
    end
  end
end
