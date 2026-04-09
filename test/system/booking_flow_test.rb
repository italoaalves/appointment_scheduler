require "application_system_test_case"
require "timeout"

class BookingFlowTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Time.find_zone("America/Sao_Paulo").local(2026, 4, 6, 8, 0, 0)

    @space = spaces(:one)
    @link = scheduling_links(:permanent_link)

    schedule = @space.availability_schedule || @space.create_availability_schedule!(timezone: "America/Sao_Paulo")
    schedule.update!(timezone: "America/Sao_Paulo")
    schedule.availability_windows.delete_all

    (0..6).each do |weekday|
      schedule.availability_windows.create!(weekday: weekday, opens_at: "09:00", closes_at: "17:00")
    end
  end

  teardown do
    travel_back
  end

  test "public booking flow progressively unlocks steps" do
    resize_window_to(1400, 900)
    visit book_path(token: @link.token)

    assert_step_state("schedule", card: "current", panel: "open")
    assert_step_state("details", card: "locked", panel: "hidden", preview: "visible")
    assert_step_state("review", card: "locked", panel: "hidden", preview: "visible")
    assert_selector "input#whatsapp_opt_in[disabled]", visible: :all
    assert_selector "button[data-booking-target='submitBtn'][disabled]", visible: :all

    assert_selector "[data-booking-target='slotsList'] .booking-slot-option", minimum: 1
    find("[data-booking-target='slotsList'] .booking-slot-option", match: :first).click
    assert_selector "[data-booking-target='slotsList'] .booking-slot-option.booking-slot-option-selected[aria-pressed='true']"

    assert_step_state("schedule", card: "complete", panel: "open")
    assert_step_state("details", card: "current", panel: "open", preview: "hidden")
    assert_step_state("review", card: "locked", panel: "hidden", preview: "visible")

    fill_in "customer_name", with: "Taylor Test"
    fill_in "customer_phone", with: "+5511999999999"

    assert_step_state("details", card: "complete", panel: "open", preview: "hidden")
    assert_step_state("review", card: "current", panel: "open", preview: "hidden")
    assert_selector "input#whatsapp_opt_in:not([disabled])"
    assert_selector "button[data-booking-target='submitBtn']:not([disabled])"
  end

  test "desktop booking layout keeps the hero in a compact sticky rail" do
    resize_window_to(1440, 900)
    visit book_path(token: @link.token)

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const shell = document.querySelector(".booking-flow-shell-sidebar")
        const heroRail = document.querySelector(".booking-flow-hero-rail")
        const heroCard = document.querySelector(".booking-hero-sticky")
        const stage = document.querySelector(".booking-flow-stage")

        const beforeTop = heroCard.getBoundingClientRect().top
        const stickyTop = parseFloat(window.getComputedStyle(heroCard).top || "0")
        window.scrollTo(0, 480)

        return {
          viewportWidth: window.innerWidth,
          shellDisplay: shell ? window.getComputedStyle(shell).display : null,
          heroWidth: heroRail ? heroRail.getBoundingClientRect().width : 0,
          stageWidth: stage ? stage.getBoundingClientRect().width : 0,
          beforeTop,
          afterTop: heroCard.getBoundingClientRect().top,
          stickyTop
        }
      })()
    JS

    assert_equal "grid", metrics["shellDisplay"]
    assert_operator metrics["stageWidth"], :>, metrics["heroWidth"]
    assert_operator metrics["heroWidth"], :<, metrics["viewportWidth"] * 0.4
    assert_in_delta metrics["stickyTop"], metrics["afterTop"], 2.5
    assert_operator metrics["afterTop"], :<=, metrics["beforeTop"] + 1
  ensure
    page.execute_script("window.scrollTo(0, 0)")
  end

  test "mobile hero compacts after scrolling" do
    resize_window_to(390, 844)
    visit book_path(token: @link.token)

    hero_styles = page.evaluate_script(<<~JS)
      (() => {
        const hero = document.querySelector(".booking-hero")
        const styles = window.getComputedStyle(hero)

        return {
          backgroundColor: styles.backgroundColor,
          borderTopWidth: styles.borderTopWidth
        }
      })()
    JS

    assert_selector "[data-booking-target='slotsList'] .booking-slot-option", minimum: 1
    assert_no_selector ".booking-page.booking-page-mobile-hero-compact", visible: :all
    assert_selector ".booking-hero-mobile-expanded", visible: :all
    assert_no_selector ".booking-hero-mobile-compact", visible: true
    assert_text I18n.t("booking.hero.subtitle")
    refute_includes [ "transparent", "rgba(0, 0, 0, 0)" ], hero_styles["backgroundColor"]
    refute_equal "0px", hero_styles["borderTopWidth"]

    page.execute_script(<<~JS)
      window.scrollTo(0, 120)
      document.dispatchEvent(new Event("scroll"))
      window.dispatchEvent(new Event("scroll"))
    JS

    assert_selector ".booking-page.booking-page-mobile-hero-compact", visible: :all
    assert_no_selector ".booking-hero-mobile-expanded", visible: true
    assert_selector ".booking-hero-mobile-compact", visible: true
    assert_no_text I18n.t("booking.hero.subtitle")
    assert_text I18n.t("booking.summary.duration_minutes", count: @space.slot_duration_minutes)
  ensure
    page.execute_script("window.scrollTo(0, 0)")
  end

  test "mobile hero compacts when changing the form" do
    resize_window_to(390, 844)
    visit book_path(token: @link.token)

    assert_no_selector ".booking-page.booking-page-mobile-hero-compact", visible: :all

    page.execute_script(<<~JS)
      const input = document.querySelector("#booking_date")
      input.value = "2026-04-07"
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    assert_selector ".booking-page.booking-page-mobile-hero-compact", visible: :all
    assert_no_selector ".booking-hero-mobile-expanded", visible: true
    assert_selector ".booking-hero-mobile-compact", visible: true
  end

  test "mobile booking flow scrolls forward when the next step unlocks" do
    resize_window_to(390, 844)
    visit book_path(token: @link.token)

    assert_selector "[data-booking-target='slotsList'] .booking-slot-option", minimum: 1
    initial_metrics = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector("[data-booking-target='flowStep'][data-step-name='details']")

        return {
          cardTop: card.getBoundingClientRect().top,
          viewportHeight: window.innerHeight
        }
      })()
    JS

    find("[data-booking-target='slotsList'] .booking-slot-option", match: :first).click
    assert_step_state("details", card: "current", panel: "open", preview: "hidden")

    metrics = wait_for_step_scroll("details", initial_metrics["cardTop"])

    assert_operator metrics["scrollY"], :>, 0
    assert_operator metrics["cardTop"], :<, initial_metrics["cardTop"] - 120
  ensure
    page.execute_script("window.scrollTo(0, 0)")
  end

  private

  def resize_window_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def assert_step_state(step_name, card:, panel:, preview: nil)
    assert_selector(
      "[data-booking-target='flowStep'][data-step-name='#{step_name}'].booking-step-card-#{card}",
      visible: :all
    )
    assert_selector(
      "[data-booking-target='stepPanel'][data-step-name='#{step_name}'].booking-step-panel-#{panel}",
      visible: :all
    )

    return unless preview

    assert_selector(
      "[data-booking-target='stepPreview'][data-step-name='#{step_name}'].booking-step-preview-#{preview}",
      visible: :all
    )
  end

  def wait_for_step_scroll(step_name, initial_top)
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        metrics = page.evaluate_script(<<~JS)
          (() => {
            const card = document.querySelector("[data-booking-target='flowStep'][data-step-name='#{step_name}']")
            if (!card) return null

            return {
              cardTop: card.getBoundingClientRect().top,
              scrollY: window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0
            }
          })()
        JS

        next unless metrics

        aligned = metrics["scrollY"] > 0 && metrics["cardTop"] < initial_top - 120

        return metrics if aligned

        sleep 0.05
      end
    end
  end
end
