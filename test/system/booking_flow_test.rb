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

  test "live slot refresh animates a booked slot before removing it" do
    resize_window_to(1400, 900)
    visit book_path(token: @link.token)

    target_date = Time.current.in_time_zone(@space.effective_timezone).to_date
    live_slots = BookingSlotsSerializer.to_json(
      @space.available_slots(from_date: target_date, to_date: target_date, limit: 3)
    )

    assert_operator live_slots.length, :>=, 2

    removed_slot = live_slots.first
    remaining_slots = live_slots.drop(1)

    assert_selector ".booking-slot-option[data-slot-value='#{removed_slot[:value]}']"

    page.execute_script(<<~JS)
      window.__bookingTestOriginalFetch = window.fetch
      window.fetch = () => Promise.resolve({
        ok: true,
        json: () => Promise.resolve(#{remaining_slots.to_json})
      })

      const element = document.querySelector("[data-controller~='booking']")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "booking")
      const syncTarget = controller.slotsSyncTarget

      syncTarget.dataset.refreshKey = "test-live-refresh"
      controller.slotsSyncTargetConnected(syncTarget)
    JS

    assert_selector ".booking-slot-option-removing[data-slot-value='#{removed_slot[:value]}']"
    assert_selector "[data-booking-target='slotsStatus']", text: I18n.t("booking.refreshing_slots")
    assert_no_selector ".booking-slot-option[data-slot-value='#{removed_slot[:value]}']"
    assert_selector ".booking-slot-option[data-slot-value='#{remaining_slots.first[:value]}']"
  ensure
    page.execute_script(<<~JS)
      if (window.__bookingTestOriginalFetch) {
        window.fetch = window.__bookingTestOriginalFetch
        delete window.__bookingTestOriginalFetch
      }
    JS
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
    initial_state = mobile_hero_state

    assert initial_state["ready"]
    assert_operator initial_state["progress"], :<, 0.12
    assert_operator initial_state["expandedOpacity"], :>, 0.9
    assert_operator initial_state["compactOpacity"], :<, 0.12
    refute_includes [ "transparent", "rgba(0, 0, 0, 0)" ], hero_styles["backgroundColor"]
    refute_equal "0px", hero_styles["borderTopWidth"]

    page.execute_script(<<~JS)
      window.scrollTo(0, 120)
      document.dispatchEvent(new Event("scroll"))
      window.dispatchEvent(new Event("scroll"))
    JS

    compacted_state = wait_for_mobile_hero_compaction(min_progress: 0.9)

    assert_operator compacted_state["progress"], :>, 0.8
    assert_operator compacted_state["compactOpacity"], :>, 0.75
    assert_operator compacted_state["expandedOpacity"], :<, 0.25
    assert_operator compacted_state["stageHeight"], :<, initial_state["stageHeight"] - 40
    assert_operator compacted_state["heroPaddingTop"], :<, initial_state["heroPaddingTop"]
    assert_text I18n.t("booking.summary.duration_minutes", count: @space.slot_duration_minutes)
  ensure
    page.execute_script("window.scrollTo(0, 0)")
  end

  test "mobile hero compacts when changing the form" do
    resize_window_to(390, 844)
    visit book_path(token: @link.token)

    initial_state = mobile_hero_state

    assert initial_state["ready"]
    assert_operator initial_state["progress"], :<, 0.12

    page.execute_script(<<~JS)
      const input = document.querySelector("#booking_date")
      input.value = "2026-04-07"
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    compacted_state = wait_for_mobile_hero_compaction(min_progress: 0.9)

    assert_operator compacted_state["progress"], :>, 0.9
    assert_operator compacted_state["compactOpacity"], :>, 0.8
    assert_operator compacted_state["expandedOpacity"], :<, 0.2
    assert_operator compacted_state["stageHeight"], :<, initial_state["stageHeight"] - 40
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

  def mobile_hero_state
    page.evaluate_script(<<~JS)
      (() => {
        const pageRoot = document.querySelector(".booking-page")
        const hero = document.querySelector(".booking-hero")
        const stage = document.querySelector(".booking-hero-mobile-stage")
        const expanded = document.querySelector(".booking-hero-mobile-expanded")
        const compact = document.querySelector(".booking-hero-mobile-compact")
        if (!pageRoot || !hero || !stage || !expanded || !compact) return null

        const heroStyles = window.getComputedStyle(hero)
        const expandedStyles = window.getComputedStyle(expanded)
        const compactStyles = window.getComputedStyle(compact)
        const progress = Number.parseFloat(heroStyles.getPropertyValue("--booking-hero-compact-progress")) || 0

        return {
          ready: pageRoot.classList.contains("booking-page-mobile-hero-ready"),
          progress,
          expandedOpacity: Number.parseFloat(expandedStyles.opacity) || 0,
          compactOpacity: Number.parseFloat(compactStyles.opacity) || 0,
          heroPaddingTop: Number.parseFloat(heroStyles.paddingTop) || 0,
          stageHeight: stage.getBoundingClientRect().height || 0
        }
      })()
    JS
  end

  def wait_for_mobile_hero_compaction(min_progress: 0.8)
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        state = mobile_hero_state
        next unless state

        compacted = state["ready"] &&
                    state["progress"] >= min_progress &&
                    state["compactOpacity"] > 0.7 &&
                    state["expandedOpacity"] < 0.3

        return state if compacted

        sleep 0.05
      end
    end
  end
end
