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

  test "mobile sticky layout keeps notification above breadcrumbs near the dock" do
    visit edit_settings_space_path

    find("button[aria-label='#{I18n.t("notifications.in_app.dropdown.title")}']").click

    assert_selector "[data-role='mobile-notification-menu']:not(.hidden)", visible: :all
    assert_selector "[data-role='notification-dropdown-panel'].glass-frosty", visible: :visible
    assert_no_selector "[data-role='mobile-notification-menu'] button[aria-label='#{I18n.t("notifications.in_app.dropdown.title")}']",
                       visible: :all
    assert_selector "[data-role='settings-action-bar']", visible: :all
    assert_selector "[data-role='mobile-breadcrumbs']", visible: :all

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const trigger = document.querySelector("[data-role='mobile-notification-trigger']");
        const menu = document.querySelector("[data-role='mobile-notification-menu']");
        const actionBar = document.querySelector("[data-role='settings-action-bar-panel']");
        const breadcrumbs = document.querySelector("[data-role='mobile-breadcrumbs']");
        const saveButton = document.querySelector("[data-role='settings-action-bar'] .btn-primary");
        const dock = document.querySelector("#dock nav");

        if (!trigger || !menu || !dock || !actionBar || !breadcrumbs || !saveButton) return null;

        const triggerRect = trigger.getBoundingClientRect();
        const menuRect = menu.getBoundingClientRect();
        const actionRect = actionBar.getBoundingClientRect();
        const breadcrumbsRect = breadcrumbs.getBoundingClientRect();
        const saveRect = saveButton.getBoundingClientRect();
        const saveStyles = window.getComputedStyle(saveButton);
        const dockRect = dock.getBoundingClientRect();

        return {
          triggerTop: triggerRect.top,
          triggerBottom: triggerRect.bottom,
          menuTop: menuRect.top,
          menuBottom: menuRect.bottom,
          actionTop: actionRect.top,
          actionBottom: actionRect.bottom,
          actionRight: actionRect.right,
          actionWidth: actionRect.width,
          breadcrumbsLeft: breadcrumbsRect.left,
          breadcrumbsTop: breadcrumbsRect.top,
          breadcrumbsBottom: breadcrumbsRect.bottom,
          dockTop: dockRect.top,
          viewportWidth: window.innerWidth,
          saveBackgroundImage: saveStyles.backgroundImage,
          saveBackdropFilter: saveStyles.backdropFilter || saveStyles.webkitBackdropFilter,
          saveWidth: saveRect.width
        };
      })()
    JS

    assert metrics.present?
    assert_operator metrics["actionTop"], :>, metrics["triggerBottom"]
    assert_operator metrics["breadcrumbsTop"], :>, metrics["triggerBottom"]
    assert_operator metrics["dockTop"], :>, metrics["actionBottom"]
    assert_operator metrics["dockTop"], :>, metrics["breadcrumbsBottom"]
    assert_operator metrics["triggerTop"], :>, metrics["menuBottom"]
    assert_operator metrics["breadcrumbsLeft"], :>, metrics["actionRight"] - 1
    assert_operator metrics["viewportWidth"] * 0.75, :>, metrics["actionWidth"]
    assert_includes metrics["saveBackgroundImage"], "gradient"
    refute_equal "none", metrics["saveBackdropFilter"]
    assert_operator metrics["saveWidth"], :>, metrics["actionWidth"] * 0.6
  end
end
