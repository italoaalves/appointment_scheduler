require "application_system_test_case"

class MobileNotificationDropdownTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @manager = users(:manager)
    Warden.test_mode!
    login_as(@manager, scope: :user)
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  teardown do
    Warden.test_reset!
  end

  test "mobile notification panel opens above the dock without nesting another trigger" do
    visit dashboard_path

    find("button[aria-label='#{I18n.t("notifications.in_app.dropdown.title")}']").click

    assert_selector "[data-role='mobile-notification-menu']:not(.hidden)", visible: :all
    assert_selector "[data-role='notification-dropdown-panel']", visible: :visible
    assert_no_selector "[data-role='mobile-notification-menu'] button[aria-label='#{I18n.t("notifications.in_app.dropdown.title")}']",
                       visible: :all

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const trigger = document.querySelector("[data-role='mobile-notification-trigger']");
        const menu = document.querySelector("[data-role='mobile-notification-menu']");
        const dock = document.querySelector("#dock nav");

        if (!trigger || !menu || !dock) return null;

        const triggerRect = trigger.getBoundingClientRect();
        const menuRect = menu.getBoundingClientRect();
        const dockRect = dock.getBoundingClientRect();

        return {
          triggerTop: triggerRect.top,
          triggerBottom: triggerRect.bottom,
          menuBottom: menuRect.bottom,
          dockTop: dockRect.top
        };
      })()
    JS

    assert metrics.present?
    assert_operator metrics["dockTop"], :>, metrics["triggerBottom"]
    assert_operator metrics["triggerTop"], :>, metrics["menuBottom"]
  end
end
