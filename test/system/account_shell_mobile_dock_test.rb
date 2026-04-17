require "application_system_test_case"

class AccountShellMobileDockTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  teardown do
    Warden.test_reset!
  end

  test "workspace settings shell keeps action controls above the mobile dock" do
    login_as(users(:manager), scope: :user)

    assert_shell_controls_clear_dock!(edit_settings_space_path)
  end

  test "account shells keep action controls above the mobile dock" do
    login_as(users(:manager_two), scope: :user)

    [
      edit_profile_path,
      edit_preferences_path,
      profile_security_path
    ].each do |path|
      assert_shell_controls_clear_dock!(path)
    end
  end

  private

  def assert_shell_controls_clear_dock!(path)
    visit path

    assert page.has_selector?("[data-role='settings-shell']"), "Expected #{path} to render the settings shell"
    assert_selector "#dock nav", visible: :all

    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const shell = document.querySelector("[data-role='settings-shell']")
        const dock = document.querySelector("#dock nav")
        const actionBar = document.querySelector("[data-role='settings-action-bar-panel']")

        if (!shell || !dock) return null

        const controlSelectors = [
          ".btn-primary",
          ".btn-secondary",
          ".btn-danger",
          ".btn-success",
          ".btn-cancel",
          ".btn-muted",
          ".btn-neutral"
        ].join(", ")

        const visibleShellControls = [...shell.querySelectorAll(controlSelectors)]
          .filter((element) => {
            const rect = element.getBoundingClientRect()
            const styles = window.getComputedStyle(element)

            return styles.display !== "none" &&
              styles.visibility !== "hidden" &&
              rect.width > 0 &&
              rect.height > 0
          })
          .sort((left, right) => right.getBoundingClientRect().bottom - left.getBoundingClientRect().bottom)

        const control = actionBar || visibleShellControls[0]

        if (!control) return null

        const dockRect = dock.getBoundingClientRect()
        const controlRect = control.getBoundingClientRect()

        return {
          dockTop: dockRect.top,
          controlBottom: controlRect.bottom,
          controlTop: controlRect.top
        }
      })()
    JS

    assert metrics.present?, "Expected #{path} to render a shell control to compare against the dock"
    assert_operator metrics["dockTop"], :>, metrics["controlBottom"],
                    "Expected #{path} controls to clear the dock, got #{metrics.inspect}"
  end
end
