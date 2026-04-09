require "application_system_test_case"

class SettingsLayoutTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @manager = users(:manager)
    UserPermission.find_or_create_by!(user: @manager, permission: "manage_policies")

    Warden.test_mode!
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test "settings routes keep the shell navigable without horizontal overflow" do
    pages = [
      { path: edit_settings_space_path, current: I18n.t("settings.sidebar.space") },
      { path: edit_settings_space_availability_path, current: I18n.t("settings.sidebar.availability") },
      { path: edit_settings_space_policies_path, current: I18n.t("settings.sidebar.policies") },
      { path: settings_whatsapp_path, current: I18n.t("settings.sidebar.whatsapp") },
      { path: settings_billing_path, current: I18n.t("settings.sidebar.billing") },
      { path: settings_credits_path, current: I18n.t("settings.sidebar.credits") }
    ]

    [
      [ 390, 844, :mobile ],
      [ 768, 1024, :desktop ],
      [ 1440, 900, :desktop ]
    ].each do |width, height, rail_variant|
      resize_window_to(width, height)

      pages.each do |page_config|
        visit page_config[:path]

        assert_selector "[data-role='settings-shell']"
        assert_selector "[data-role='settings-intro']"
        assert_selector "[aria-current='page']", text: page_config[:current], visible: :all
        assert_text I18n.t("settings.sidebar.whatsapp")
        assert_settings_rail_layout!(rail_variant)
        assert_settings_intro_layout!(rail_variant)
        assert_settings_rail_sticks!(rail_variant)
        assert_no_horizontal_overflow!
      end
    end
  end

  private

  def resize_window_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def assert_no_horizontal_overflow!
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const viewportWidth = window.innerWidth
        const docWidth = Math.max(
          document.documentElement.scrollWidth,
          document.body.scrollWidth
        )

        return { viewportWidth, docWidth }
      })()
    JS

    assert_operator metrics["docWidth"], :<=, metrics["viewportWidth"] + 1,
                    "Expected settings layout to fit viewport width, got #{metrics.inspect}"
  end

  def assert_settings_rail_layout!(expected)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const shell = document.querySelector("[data-role='settings-shell']")
        const sidebar = document.querySelector("[data-role='settings-sidebar']")
        const mobile = document.querySelector(".settings-sidebar-mobile")
        const desktop = document.querySelector(".settings-sidebar-desktop")
        const desktopCard = document.querySelector("[data-role='settings-sidebar-card']")

        return {
          viewportWidth: window.innerWidth,
          shellDisplay: shell ? window.getComputedStyle(shell).display : null,
          sidebarWidth: sidebar ? sidebar.getBoundingClientRect().width : null,
          sidebarPosition: sidebar ? window.getComputedStyle(sidebar).position : null,
          mobile: mobile ? window.getComputedStyle(mobile).display : null,
          desktop: desktop ? window.getComputedStyle(desktop).display : null,
          desktopOverflow: desktopCard ? window.getComputedStyle(desktopCard).overflowY : null
        }
      })()
    JS

    if expected == :mobile
      assert_equal "block", metrics["mobile"]
      assert_equal "none", metrics["desktop"]
      assert_equal "sticky", metrics["sidebarPosition"]
      assert_equal "flex", metrics["shellDisplay"]
    else
      assert_equal "none", metrics["mobile"]
      assert_equal "block", metrics["desktop"]
      assert_equal "sticky", metrics["sidebarPosition"]
      assert_equal "grid", metrics["shellDisplay"]
      assert_equal "auto", metrics["desktopOverflow"]
      assert_in_delta metrics["viewportWidth"] * 0.25, metrics["sidebarWidth"], 2.0
    end
  end

  def assert_settings_intro_layout!(expected)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const introCard = document.querySelector(".settings-intro-card")

        return {
          introPosition: introCard ? window.getComputedStyle(introCard).position : null
        }
      })()
    JS

    if expected == :mobile
      assert_equal "static", metrics["introPosition"]
    else
      assert_equal "sticky", metrics["introPosition"]
    end
  end

  def assert_settings_rail_sticks!(expected)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const shellContent = document.querySelector(".settings-shell-content")
        const sidebar = document.querySelector("[data-role='settings-sidebar']")
        const introCard = document.querySelector(".settings-intro-card")

        if (shellContent && !document.querySelector("[data-role='sticky-test-spacer']")) {
          const spacer = document.createElement("div")
          spacer.dataset.role = "sticky-test-spacer"
          spacer.style.height = "1600px"
          spacer.style.pointerEvents = "none"
          spacer.setAttribute("aria-hidden", "true")
          shellContent.appendChild(spacer)
        }

        if (!sidebar) {
          return null
        }

        window.scrollTo(0, 0)

        const stickyTop = parseFloat(window.getComputedStyle(sidebar).top || "0")
        const before = sidebar.getBoundingClientRect().top
        const maxScroll = Math.max(
          document.documentElement.scrollHeight - window.innerHeight,
          0
        )

        window.scrollTo(0, Math.min(480, maxScroll))

        return {
          before,
          after: sidebar.getBoundingClientRect().top,
          stickyTop,
          maxScroll,
          introTop: introCard ? parseFloat(window.getComputedStyle(introCard).top || "0") : null,
          introAfter: introCard ? introCard.getBoundingClientRect().top : null
        }
      })()
    JS

    assert metrics.present?
    assert_operator metrics["maxScroll"], :>, 0
    assert_in_delta metrics["stickyTop"], metrics["after"], 2.5
    assert_operator metrics["after"], :<=, metrics["before"] + 1

    return if expected == :mobile

    assert_in_delta metrics["introTop"], metrics["introAfter"], 2.5
  ensure
    page.execute_script(<<~JS)
      (() => {
        const spacer = document.querySelector("[data-role='sticky-test-spacer']")
        if (spacer) spacer.remove()
        window.scrollTo(0, 0)
      })()
    JS
  end
end
