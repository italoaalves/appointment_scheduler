require "application_system_test_case"

class MobileDockScrollEndTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
    login_as(users(:manager), scope: :user)
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  teardown do
    Warden.test_reset!
  end

  test "default layout pages leave scroll-end space above the mobile dock" do
    [
      dashboard_path,
      appointments_path
    ].each do |path|
      visit path

      assert_selector "#dock nav", visible: :all

      page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const dock = document.querySelector("#dock nav")
          const main = document.querySelector("main")

          if (!dock || !main) return null

          const visibleChildren = [...main.children].filter((element) => {
            const rect = element.getBoundingClientRect()
            const styles = window.getComputedStyle(element)

            return styles.display !== "none" &&
              styles.visibility !== "hidden" &&
              rect.width > 0 &&
              rect.height > 0
          })

          const lastChild = visibleChildren[visibleChildren.length - 1]

          if (!lastChild) return null

          return {
            dockTop: dock.getBoundingClientRect().top,
            contentBottom: lastChild.getBoundingClientRect().bottom
          }
        })()
      JS

      assert metrics.present?, "Expected #{path} to render content inside the main shell"
      assert_operator metrics["dockTop"], :>, metrics["contentBottom"],
                      "Expected #{path} content to stop above the dock, got #{metrics.inspect}"
    end
  end

  test "inbox shell stops above the mobile dock" do
    visit spaces_inbox_index_path

    assert_selector "#dock nav", visible: :all
    assert_selector "[data-role='inbox-shell']"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const dock = document.querySelector("#dock nav")
        const shell = document.querySelector("[data-role='inbox-shell']")

        if (!dock || !shell) return null

        return {
          dockTop: dock.getBoundingClientRect().top,
          shellBottom: shell.getBoundingClientRect().bottom
        }
      })()
    JS

    assert metrics.present?, "Expected inbox shell metrics to be measurable"
    assert_operator metrics["dockTop"], :>, metrics["shellBottom"],
                    "Expected inbox shell to stop above the dock, got #{metrics.inspect}"
  end
end
