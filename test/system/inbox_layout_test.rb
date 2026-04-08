require "application_system_test_case"

class InboxLayoutTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @manager = users(:manager)
    @conversation = conversations(:needs_reply_one)
    18.times do |index|
      @conversation.conversation_messages.create!(
        direction: index.even? ? :inbound : :outbound,
        status: index.even? ? :read : :delivered,
        body: "Overflow message #{index}",
        message_type: "text",
        sent_by: index.odd? ? @manager : nil,
        created_at: 20.minutes.ago + index.minutes
      )
    end
    @latest_body = "Latest thread anchor"
    @conversation.conversation_messages.create!(
      direction: :outbound,
      status: :delivered,
      body: @latest_body,
      message_type: "text",
      sent_by: @manager,
      created_at: Time.current
    )
    Warden.test_mode!
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test "mobile inbox keeps the list full width and opens conversations as a separate screen" do
    resize_window_to(390, 844)

    visit spaces_inbox_index_path

    assert_no_horizontal_overflow!

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector("[data-inbox-target='listPanel']")
        const detail = document.querySelector("[data-inbox-target='detailPanel']")
        const listRect = list.getBoundingClientRect()

        return {
          viewportWidth: window.innerWidth,
          listWidth: listRect.width,
          detailHidden: detail ? window.getComputedStyle(detail).display === "none" : true
        }
      })()
    JS

    assert_operator metrics["listWidth"], :>=, metrics["viewportWidth"] * 0.95
    assert metrics["detailHidden"], "expected the desktop detail panel to stay hidden on mobile"

    click_link @conversation.contact_name

    assert_current_path spaces_inbox_path(@conversation)
    assert_no_horizontal_overflow!
    assert_selector "[data-role='conversation-header-shell']", visible: :all
    assert_selector "[data-role='conversation-header'].glass-frosty", visible: :all
    assert_selector "[data-role='conversation-composer'].glass-frosty", visible: :all
    assert_text @latest_body
    assert_selector "a[data-turbo-frame='_top']"
    assert_selector "[data-role='conversation-scroll-region'][data-scroll-ready='true']", visible: :all

    initial_metrics = page.evaluate_script(<<~JS)
      (() => {
        const region = document.querySelector("[data-role='conversation-scroll-region']")
        const messages = document.querySelector("[data-role='conversation-messages']")
        const composer = document.querySelector("[data-role='conversation-composer']")
        const lastMessage = messages.lastElementChild

        return {
          scrollTop: region.scrollTop,
          maxScroll: region.scrollHeight - region.clientHeight,
          lastBottom: lastMessage.getBoundingClientRect().bottom,
          composerTop: composer.getBoundingClientRect().top
        }
      })()
    JS

    assert_operator initial_metrics["maxScroll"], :>, 0, "Expected overflowing conversation fixture, got #{initial_metrics.inspect}"
    assert_in_delta initial_metrics["maxScroll"], initial_metrics["scrollTop"], 4, "Expected conversation to open near the bottom, got #{initial_metrics.inspect}"
    assert_operator initial_metrics["lastBottom"], :<=, initial_metrics["composerTop"] + 8, "Expected latest message to sit above composer, got #{initial_metrics.inspect}"

    sticky_metrics = page.evaluate_script(<<~JS)
      (() => {
        const region = document.querySelector("[data-role='conversation-scroll-region']")
        const messages = document.querySelector("[data-role='conversation-messages']")
        const header = document.querySelector("[data-role='conversation-header']")
        const composer = document.querySelector("[data-role='conversation-composer']")

        for (let i = 0; i < 30; i += 1) {
          const row = document.createElement("div")
          row.className = "flex justify-start"
          row.style.marginBottom = "12px"
          row.innerHTML = `
            <div class="max-w-[78%] rounded-2xl px-3.5 py-2.5 text-sm shadow-sm bg-white text-deep rounded-bl-sm border border-slate-200" style="min-height: 96px;">
              <p class="whitespace-pre-wrap break-words leading-relaxed">Sticky filler ${i}</p>
            </div>
          `
          messages.appendChild(row)
        }

        const beforeTop = header.getBoundingClientRect().top
        const beforeBottom = composer.getBoundingClientRect().bottom
        const beforeWindowScroll = window.scrollY
        const maxScroll = region.scrollHeight - region.clientHeight
        region.scrollTop = maxScroll
        const afterTop = header.getBoundingClientRect().top
        const afterBottom = composer.getBoundingClientRect().bottom

        return {
          scrolled: region.scrollTop,
          maxScroll,
          beforeWindowScroll,
          afterWindowScroll: window.scrollY,
          beforeTop,
          afterTop,
          beforeBottom,
          afterBottom
        }
      })()
    JS

    assert_operator sticky_metrics["scrolled"], :>, 0, "Expected message region to scroll, got #{sticky_metrics.inspect}"
    assert_equal sticky_metrics["beforeWindowScroll"], sticky_metrics["afterWindowScroll"], "Expected page scroll to stay unchanged, got #{sticky_metrics.inspect}"
    assert_in_delta sticky_metrics["beforeTop"], sticky_metrics["afterTop"], 1, "Expected header to remain pinned, got #{sticky_metrics.inspect}"
    assert_in_delta sticky_metrics["beforeBottom"], sticky_metrics["afterBottom"], 1, "Expected composer to remain pinned, got #{sticky_metrics.inspect}"
  end

  test "desktop inbox keeps the list and detail panels side by side" do
    resize_window_to(1400, 900)

    visit spaces_inbox_index_path(id: @conversation.id)

    assert_no_horizontal_overflow!

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector("[data-inbox-target='listPanel']")
        const detail = document.querySelector("[data-inbox-target='detailPanel']")
        const listRect = list.getBoundingClientRect()
        const detailRect = detail.getBoundingClientRect()

        return {
          listWidth: listRect.width,
          detailWidth: detailRect.width,
          sideBySide: detailRect.left >= listRect.right - 1
        }
      })()
    JS

    assert_in_delta 320, metrics["listWidth"], 10
    assert_operator metrics["detailWidth"], :>, metrics["listWidth"]
    assert metrics["sideBySide"], "expected inbox panels to remain side by side on desktop"
    assert_selector "[data-conversation-id='#{@conversation.id}'].bg-electric\\/5", visible: :all
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
                    "Expected inbox to fit viewport width, got #{metrics.inspect}"
  end
end
