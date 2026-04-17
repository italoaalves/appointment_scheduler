# frozen_string_literal: true

require "test_helper"

module Spaces
  class AutomationControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @space = spaces(:one)
    end

    test "show renders automation settings page for dashboard users" do
      sign_in @secretary

      get settings_automation_path

      assert_response :success
      assert_includes response.body, I18n.t("automation.title")
      assert_includes response.body, "turbo-frame"
    end

    test "show redirects unauthenticated users" do
      get settings_automation_path

      assert_redirected_to new_user_session_path
    end

    test "update persists automation settings" do
      sign_in @manager

      patch settings_automation_path, params: {
        space: {
          appointment_automation_enabled: "1",
          confirmation_lead_hours: [ "48", "6", "" ],
          confirmation_quiet_hours_start: "21:00",
          confirmation_quiet_hours_end: "07:00"
        }
      }

      assert_redirected_to settings_automation_path

      @space.reload
      assert @space.appointment_automation_enabled?
      assert_equal [ 48, 6 ], @space.confirmation_lead_hours
      assert_equal "21:00:00", @space.confirmation_quiet_hours_start.strftime("%H:%M:%S")
      assert_equal "07:00:00", @space.confirmation_quiet_hours_end.strftime("%H:%M:%S")
    end

    test "update allows dashboard users without manage_space permission" do
      sign_in @secretary

      patch settings_automation_path, params: {
        space: {
          appointment_automation_enabled: "1",
          confirmation_lead_hours: [ "24", "2" ],
          confirmation_quiet_hours_start: "22:00",
          confirmation_quiet_hours_end: "08:00"
        }
      }

      assert_redirected_to settings_automation_path
      assert spaces(:one).reload.appointment_automation_enabled?
    end

    test "update re-renders page when settings are invalid" do
      sign_in @manager

      patch settings_automation_path, params: {
        space: {
          appointment_automation_enabled: "1",
          confirmation_lead_hours: [ "" ],
          confirmation_quiet_hours_start: "22:00",
          confirmation_quiet_hours_end: "08:00"
        }
      }

      assert_response :unprocessable_entity
      assert_includes response.body, I18n.t("errors.messages.blank")
    end
  end
end
