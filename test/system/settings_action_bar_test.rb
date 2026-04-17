require "application_system_test_case"

class SettingsActionBarTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @manager = users(:manager_two)
    Warden.test_mode!
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test "dirty save forms reveal a sticky desktop action bar and show success feedback" do
    resize_window_to(1280, 900)
    visit edit_preferences_path

    assert_selector "[data-role='settings-action-bar'].hidden", visible: :all

    page.execute_script(<<~JS)
      (() => {
        const select = document.querySelector("select[name='user_preference[locale]']")
        select.selectedIndex = (select.selectedIndex + 1) % select.options.length
        select.dispatchEvent(new Event("change", { bubbles: true }))
      })()
    JS

    assert_no_selector "[data-role='settings-action-bar'].hidden", visible: :all

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const actionBar = document.querySelector("[data-role='settings-action-bar']")
        return actionBar ? {
          position: window.getComputedStyle(actionBar).position,
          bottom: window.getComputedStyle(actionBar).bottom
        } : null
      })()
    JS

    assert_equal "sticky", metrics["position"]
    refute_equal "auto", metrics["bottom"]

    find("[data-role='settings-action-bar'] .btn-primary", visible: :all).click

    assert_current_path edit_preferences_path
    assert_selector "[data-role='settings-action-bar-status'][data-feedback-state='success']",
                    visible: :all
  end

  test "dirty save forms keep the mobile action bar transparent and show error feedback on failure" do
    resize_window_to(390, 844)
    visit new_profile_security_totp_enrollment_path

    assert_selector "[data-role='settings-action-bar'].hidden", visible: :all

    fill_in "code", with: "000000"

    assert_no_selector "[data-role='settings-action-bar'].hidden", visible: :all

    panel_styles = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("[data-role='settings-action-bar-panel']")
        if (!panel) return null

        const styles = window.getComputedStyle(panel)
        return {
          backgroundColor: styles.backgroundColor,
          boxShadow: styles.boxShadow,
          borderTopWidth: styles.borderTopWidth
        }
      })()
    JS

    assert_equal "rgba(0, 0, 0, 0)", panel_styles["backgroundColor"]
    assert_equal "none", panel_styles["boxShadow"]
    assert_equal "0px", panel_styles["borderTopWidth"]

    find("[data-role='settings-action-bar'] .btn-primary", visible: :all).click

    assert_text I18n.t("mfa.totp_enrollment.errors.invalid_code")
    assert_selector "[data-role='settings-action-bar-status'][data-feedback-state='error']",
                    visible: :all
  end

  private

  def resize_window_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end
