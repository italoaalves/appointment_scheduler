# frozen_string_literal: true

require "test_helper"

module Spaces
  class SpaceControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @space = spaces(:one)
    end

    test "manager can upload a space banner from settings" do
      sign_in @manager

      patch settings_space_path, params: {
        space: {
          name: @space.name,
          banner_upload: image_upload(filename: "banner.png")
        }
      }

      assert_redirected_to edit_settings_space_path
      assert @space.reload.banner_file.present?

      get settings_space_banner_path

      assert_response :success
      assert_equal "image/png", response.media_type
    end

    test "manager can remove a stored space banner" do
      sign_in @manager
      patch settings_space_path, params: {
        space: {
          name: @space.name,
          banner_upload: image_upload(filename: "banner.png")
        }
      }

      assert @space.reload.banner_file.present?

      delete settings_space_banner_path

      assert_redirected_to edit_settings_space_path
      assert_nil @space.reload.banner_file
    end

    test "space settings reject invalid banner uploads" do
      sign_in @manager

      patch settings_space_path, params: {
        space: {
          name: @space.name,
          banner_upload: text_upload
        }
      }

      assert_response :unprocessable_entity
      assert_nil @space.reload.banner_file
    end
  end
end
