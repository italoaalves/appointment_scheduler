require "application_system_test_case"

class InboxMobileLayoutTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @manager = users(:manager)
    @conversation = conversations(:needs_reply_one)
    Warden.test_mode!
    login_as(@manager, scope: :user)
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  teardown do
    Warden.test_reset!
  end

  test "inbox list fits within the mobile viewport after returning from a conversation" do
    visit spaces_inbox_index_path
    assert_mobile_width_fits!

    assert_text @conversation.contact_name
    click_link @conversation.contact_name
    assert_current_path %r{/inbox/\d+}

    page.go_back
    assert_current_path spaces_inbox_index_path

    assert_mobile_width_fits!
  end

  private

  def assert_mobile_width_fits!
    scroll_metrics = page.evaluate_script(<<~JS)
      (() => {
        const viewportWidth = window.innerWidth
        const docWidth = Math.max(
          document.documentElement.scrollWidth,
          document.body.scrollWidth
        )

        const offenders = Array.from(document.querySelectorAll("body *"))
          .filter((element) => {
            const style = window.getComputedStyle(element)
            if (style.display === "none" || style.position === "fixed") return false

            const rect = element.getBoundingClientRect()
            return rect.right > viewportWidth + 1 || rect.left < -1 || rect.width > viewportWidth + 1
          })
          .slice(0, 10)
          .map((element) => {
            const rect = element.getBoundingClientRect()

            return {
              tag: element.tagName.toLowerCase(),
              id: element.id,
              classes: element.className,
              width: rect.width,
              left: rect.left,
              right: rect.right,
              text: element.textContent.trim().slice(0, 80)
            }
          })

        return { viewportWidth, docWidth, offenders }
      })()
    JS

    assert_operator scroll_metrics["docWidth"], :<=, scroll_metrics["viewportWidth"] + 1,
                    "Expected mobile inbox to fit viewport, but offenders were: #{scroll_metrics["offenders"].inspect}"
  end
end
