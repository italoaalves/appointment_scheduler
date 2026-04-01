# frozen_string_literal: true

require "test_helper"

module Spaces
  class WhatsappSettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager   = users(:manager)    # spaces(:one) — has manage_space permission
      @secretary = users(:secretary)  # spaces(:one) — no manage_space permission
    end

    # ── show ─────────────────────────────────────────────────────────────────

    test "show renders whatsapp settings page for manager" do
      sign_in @manager

      get settings_whatsapp_path

      assert_response :success
      assert_includes response.body, I18n.t("spaces.whatsapp_settings.title")
    end

    test "show displays connected number when space has an active number" do
      sign_in @manager
      # spaces(:one) has whatsapp_phone_numbers(:space_number) fixture (active)

      get settings_whatsapp_path

      assert_response :success
      assert_includes response.body, whatsapp_phone_numbers(:space_number).display_number
    end

    test "show displays connect button when no number is connected" do
      sign_in @manager
      whatsapp_phone_numbers(:space_number).update!(status: :disconnected)

      get settings_whatsapp_path

      assert_response :success
      assert_includes response.body, I18n.t("spaces.whatsapp_settings.connect_button")
    end

    test "show redirects unauthenticated users" do
      get settings_whatsapp_path

      assert_redirected_to new_user_session_path
    end

    test "show redirects secretary without manage_space permission" do
      sign_in @secretary

      get settings_whatsapp_path

      assert_redirected_to root_path
    end

    # ── connect ──────────────────────────────────────────────────────────────

    test "connect creates a WhatsappPhoneNumber for the space" do
      sign_in @manager
      whatsapp_phone_numbers(:space_number).destroy

      with_successful_verification do
        post connect_settings_whatsapp_path, params: {
          whatsapp_phone_number: {
            phone_number_id: "new_phone_id_123",
            display_number: "+55 11 91234-5678",
            waba_id: "waba_abc",
            verified_name: "Test Clinic"
          }
        }
      end

      assert_redirected_to settings_whatsapp_path
      assert_equal I18n.t("spaces.whatsapp_settings.connected"), flash[:notice]
      assert spaces(:one).whatsapp_phone_number.active?
    end

    test "connect rejects params with missing required fields" do
      sign_in @manager
      whatsapp_phone_numbers(:space_number).destroy

      with_successful_verification do
        post connect_settings_whatsapp_path, params: {
          whatsapp_phone_number: {
            phone_number_id: "",
            display_number: "+55 11 91234-5678",
            waba_id: "waba_abc",
            verified_name: "Test Clinic"
          }
        }
      end

      assert_redirected_to settings_whatsapp_path
      assert flash[:alert].present?
    end

    test "connect redirects with alert when ownership verification fails" do
      sign_in @manager
      whatsapp_phone_numbers(:space_number).destroy

      with_failed_verification do
        post connect_settings_whatsapp_path, params: {
          whatsapp_phone_number: {
            phone_number_id: "bad_id",
            display_number: "+55 11 91234-5678",
            waba_id: "waba_abc",
            verified_name: "Test Clinic"
          }
        }
      end

      assert_redirected_to settings_whatsapp_path
      assert_equal I18n.t("spaces.whatsapp_settings.verification_failed"), flash[:alert]
    end

    test "connect handles RecordNotUnique gracefully" do
      sign_in @manager
      whatsapp_phone_numbers(:space_number).destroy

      # Simulate the race condition rescue path: a VerifyOwnership double that raises
      # RecordNotUnique when called, surfacing the rescue clause in the controller.
      # This uses the VerifyOwnership stub boundary since we cannot stub instance methods
      # without Mocha. The rescue is triggered at the verification step for simplicity.
      raising_verify = Object.new
      raising_verify.define_singleton_method(:call) { |**| raise ActiveRecord::RecordNotUnique, "duplicate" }

      Whatsapp::VerifyOwnership.stub(:new, ->(*) { raising_verify }) do
        post connect_settings_whatsapp_path, params: {
          whatsapp_phone_number: {
            phone_number_id: "dup_id",
            display_number: "+55 11 99999-9999",
            waba_id: "waba_abc",
            verified_name: "Test Clinic"
          }
        }
      end

      assert_redirected_to settings_whatsapp_path
      assert_equal I18n.t("spaces.whatsapp_settings.already_connected"), flash[:alert]
    end

    test "connect redirects unauthenticated users" do
      post connect_settings_whatsapp_path, params: {
        whatsapp_phone_number: {
          phone_number_id: "some_id",
          display_number: "+55 11 91234-5678",
          waba_id: "waba_abc",
          verified_name: "Test Clinic"
        }
      }

      assert_redirected_to new_user_session_path
    end

    test "connect redirects secretary without manage_space permission" do
      sign_in @secretary

      post connect_settings_whatsapp_path, params: {
        whatsapp_phone_number: {
          phone_number_id: "some_id",
          display_number: "+55 11 91234-5678",
          waba_id: "waba_abc",
          verified_name: "Test Clinic"
        }
      }

      assert_redirected_to root_path
    end

    # ── disconnect ───────────────────────────────────────────────────────────

    test "disconnect sets phone number status to disconnected" do
      sign_in @manager
      # spaces(:one) has whatsapp_phone_numbers(:space_number) — active

      delete disconnect_settings_whatsapp_path

      assert_redirected_to settings_whatsapp_path
      assert_equal I18n.t("spaces.whatsapp_settings.disconnected"), flash[:notice]
      assert whatsapp_phone_numbers(:space_number).reload.disconnected?
    end

    test "disconnect alerts when no number exists" do
      sign_in @manager
      whatsapp_phone_numbers(:space_number).destroy

      delete disconnect_settings_whatsapp_path

      assert_redirected_to settings_whatsapp_path
      assert_equal I18n.t("spaces.whatsapp_settings.disconnect_failed"), flash[:alert]
    end

    test "disconnect redirects unauthenticated users" do
      delete disconnect_settings_whatsapp_path

      assert_redirected_to new_user_session_path
    end

    test "disconnect redirects secretary without manage_space permission" do
      sign_in @secretary

      delete disconnect_settings_whatsapp_path

      assert_redirected_to root_path
    end

    private

    # Minitest's stub(method, val) calls val if val.respond_to?(:call), so we cannot
    # pass an object with a #call method directly. Instead we stub :new with a lambda
    # that returns a service-like object, routing via a captured variable.
    def with_successful_verification(&block)
      result = Whatsapp::VerifyOwnership::Result.new(success?: true, error: nil)
      service_double = VerifyOwnershipDouble.new(result)
      Whatsapp::VerifyOwnership.stub(:new, ->(*) { service_double }, &block)
    end

    def with_failed_verification(&block)
      result = Whatsapp::VerifyOwnership::Result.new(success?: false, error: "Phone number ID mismatch")
      service_double = VerifyOwnershipDouble.new(result)
      Whatsapp::VerifyOwnership.stub(:new, ->(*) { service_double }, &block)
    end

    class VerifyOwnershipDouble
      def initialize(result) = @result = result
      def call(**) = @result
    end
  end
end
