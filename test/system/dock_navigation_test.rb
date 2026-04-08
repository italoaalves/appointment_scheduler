require "application_system_test_case"

class DockNavigationTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @manager = users(:manager)
    Warden.test_mode!
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test "mobile dock sheets can still open and close on the dashboard" do
    resize_window_to(390, 844)

    visit dashboard_path

    find("button[data-nav-group-param='appointments']", visible: :all).click

    assert_selector "[data-nav-target='sheetOverlay']:not(.hidden)", visible: :all
    assert_selector "[data-nav-target='sheet'][data-nav-group='appointments'].translate-y-0", visible: :all

    find("[data-nav-target='sheetOverlay']", visible: :all).click

    assert_selector "[data-nav-target='sheetOverlay'].hidden", visible: :all
  end

  test "mobile dock sheets close automatically after navigating from a submenu link" do
    resize_window_to(390, 844)

    visit dashboard_path

    find("button[data-nav-group-param='appointments']", visible: :all).click
    assert_selector "[data-nav-target='sheet'][data-nav-group='appointments'].translate-y-0", visible: :all

    within("[data-nav-target='sheet'][data-nav-group='appointments']") do
      find("a[href='#{appointments_path}']", visible: :all).click
    end

    assert_current_path appointments_path
    assert_selector "[data-nav-target='sheetOverlay'].hidden", visible: :all
    assert_selector "[data-nav-target='sheet'][data-nav-group='appointments'].hidden", visible: :all
  end

  test "desktop dock flyouts stay open after navigation and close on mouse leave" do
    resize_window_to(1400, 900)

    visit dashboard_path

    find("button[data-nav-group-param='appointments']", visible: :all).click

    assert_selector "[data-nav-target='flyout'][data-nav-group='appointments']:not(.hidden)", visible: :all

    within("[data-nav-target='flyout'][data-nav-group='appointments']") do
      find("a[href='#{appointments_path}']", visible: :all).click
    end

    assert_current_path appointments_path
    assert_selector "[data-nav-target='flyout'][data-nav-group='appointments']:not(.hidden)", visible: :all

    page.execute_script(<<~JS)
      (() => {
        const button = document.querySelector("button[data-nav-group-param='appointments']")
        button.closest(".relative").dispatchEvent(new MouseEvent("mouseleave", { bubbles: true }))
      })()
    JS

    assert_selector "[data-nav-target='flyout'][data-nav-group='appointments'].hidden", visible: :all, wait: 1
  end

  test "desktop dock flyouts stay open while moving from the icon into the submenu" do
    resize_window_to(1400, 900)

    visit dashboard_path

    find("button[data-nav-group-param='appointments']", visible: :all).click
    assert_selector "[data-nav-target='flyout'][data-nav-group='appointments']:not(.hidden)", visible: :all

    page.execute_script(<<~JS)
      (() => {
        const button = document.querySelector("button[data-nav-group-param='appointments']")
        const wrapper = button.closest(".relative")
        const flyout = document.querySelector("[data-nav-target='flyout'][data-nav-group='appointments']")

        wrapper.dispatchEvent(new MouseEvent("mouseleave", { bubbles: true }))
        flyout.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }))
      })()
    JS

    sleep 0.2

    assert_selector "[data-nav-target='flyout'][data-nav-group='appointments']:not(.hidden)", visible: :all
  end

  private

  def resize_window_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end
