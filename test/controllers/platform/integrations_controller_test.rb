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

    # ── whatsapp_check ──────────────────────────────────────────────────

    test "whatsapp_check succeeds with valid credentials" do
      sign_in @admin

      stub_whatsapp_check({ "verified_name" => "Test Bot", "display_phone_number" => "+55 11 99999-0000" }) do
        post whatsapp_check_platform_integrations_path
      end

      assert_redirected_to platform_integrations_path
      assert_match "Test Bot", flash[:notice]
    end

    test "whatsapp_check reports API error" do
      sign_in @admin

      stub_whatsapp_check({ "error" => { "message" => "Invalid OAuth token" } }) do
        post whatsapp_check_platform_integrations_path
      end

      assert_redirected_to platform_integrations_path
      assert_match "Invalid OAuth token", flash[:alert]
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

    private

    def stub_whatsapp_check(response_body, &block)
      fake_response = OpenStruct.new(body: response_body.to_json)

      with_meta_credentials do
        Net::HTTP.stub(:start, ->(*_args, **_opts) { fake_response }, &block)
      end
    end

    def with_meta_credentials(&block)
      fake_creds = Object.new
      fake_creds.define_singleton_method(:dig) do |*keys|
        case keys
        when [ :meta, :access_token ]              then "fake_token"
        when [ :meta, :app_secret ]                then "fake_secret"
        when [ :meta, :verify_token ]              then "fake_verify"
        when [ :meta, :whatsapp, :phone_number_id ] then "123456789"
        end
      end
      Rails.application.stub(:credentials, fake_creds, &block)
    end
  end
end
