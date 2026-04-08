require "application_system_test_case"

class MobileDockNavigationTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  APPOINTMENTS_SHEET_SELECTOR = "[data-nav-target='sheet'][data-nav-group='appointments']".freeze

  setup do
    @manager = users(:manager)
    Warden.test_mode!
    login_as(@manager, scope: :user)
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  teardown do
    Warden.test_reset!
  end

  test "mobile submenu closes after following a sheet link" do
    visit root_path

    find("button[aria-label='Appointments']").click

    assert_selector "#{APPOINTMENTS_SHEET_SELECTOR}.translate-y-0", visible: :all

    within(APPOINTMENTS_SHEET_SELECTOR) do
      click_link I18n.t("layout.nav.customers")
    end

    assert_current_path customers_path
    assert_selector "#{APPOINTMENTS_SHEET_SELECTOR}.translate-y-full", visible: :all
    assert_no_selector "#{APPOINTMENTS_SHEET_SELECTOR}.translate-y-0", visible: :all
    assert_selector "[data-nav-target='sheetOverlay'].hidden", visible: :all
  end
end
