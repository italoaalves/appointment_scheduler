# frozen_string_literal: true

require "test_helper"

module Platform
  class IntegrationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @manager = users(:manager)
    end

    # ── auth ──────────────────────────────────────────────────────────────

    test "unauthenticated user is redirected to login" do
      get platform_integrations_path
      assert_redirected_to new_user_session_path
    end

    test "non-admin is redirected to root" do
      sign_in @manager
      get platform_integrations_path
      assert_redirected_to root_path
    end

    # ── index ─────────────────────────────────────────────────────────────

    test "admin can view integrations page" do
      sign_in @admin
      get platform_integrations_path
      assert_response :success
    end

    # ── whatsapp_test ─────────────────────────────────────────────────────

    test "whatsapp_test requires phone number" do
      sign_in @admin
      post whatsapp_test_platform_integrations_path, params: { phone: "" }
      assert_redirected_to platform_integrations_path
      assert_equal I18n.t("platform.integrations.whatsapp.phone_required"), flash[:alert]
    end

    test "whatsapp_test sends message and redirects with notice" do
      sign_in @admin

      mock_response = { "messages" => [ { "id" => "wamid.test123" } ] }
      mock_client = Minitest::Mock.new
      mock_client.expect(:send_text, mock_response, [], to: "+5511999999999", body: I18n.t("platform.integrations.whatsapp.test_message_body"))

      Whatsapp::Client.stub(:new, mock_client) do
        post whatsapp_test_platform_integrations_path, params: { phone: "+5511999999999" }
      end

      assert_redirected_to platform_integrations_path
      assert_match "wamid.test123", flash[:notice]
      mock_client.verify
    end

    test "whatsapp_test handles API error" do
      sign_in @admin

      mock_client = Minitest::Mock.new
      mock_client.expect(:send_text, nil) do |**_kwargs|
        raise Whatsapp::Client::ApiError, "Invalid phone number"
      end

      Whatsapp::Client.stub(:new, mock_client) do
        post whatsapp_test_platform_integrations_path, params: { phone: "+5511000000000" }
      end

      assert_redirected_to platform_integrations_path
      assert_match "Invalid phone number", flash[:alert]
    end
  end
end
