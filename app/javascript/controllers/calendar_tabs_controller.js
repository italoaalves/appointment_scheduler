import { Controller } from "@hotwired/stimulus"

// CSS classes for tab state (managed via classList for smooth transitions)
const TAB_ACTIVE_CLASSES   = ["calendar-tab-active"]
const TAB_INACTIVE_CLASSES = ["calendar-tab-inactive"]

export default class extends Controller {
  static targets = ["panel", "tab", "scrollArea", "stats"]
  static values = { storageKey: String }

  #activeTab = "today"

  connect() {
    const storedTab = this.#readStoredTab()

    if (this.#isValidTab(storedTab)) {
      this.#activeTab = storedTab
    }

    this.#render()
  }

  switchTab(event) {
    const tab = event.params.tab || event.currentTarget.dataset.calendarTabsTabParam
    if (!this.#isValidTab(tab)) return
    if (tab === this.#activeTab) return

    this.#activeTab = tab
    this.#persistActiveTab()
    this.#render()

    if (this.hasScrollAreaTarget) {
      this.scrollAreaTarget.scrollTo({ top: 0, behavior: "smooth" })
    }
  }

  #render() {
    // Animate panels with CSS class transition
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.tab === this.#activeTab
      panel.classList.toggle("calendar-panel-visible", isActive)
      panel.classList.toggle("calendar-panel-hidden", !isActive)
    })

    // Show/hide stats
    this.statsTargets.forEach(stats => {
      stats.hidden = stats.dataset.tab !== this.#activeTab
    })

    // Update tab styling
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.calendarTabsTabParam === this.#activeTab
      tab.classList.remove(...TAB_ACTIVE_CLASSES, ...TAB_INACTIVE_CLASSES)
      tab.classList.add(...(isActive ? TAB_ACTIVE_CLASSES : TAB_INACTIVE_CLASSES))
      tab.setAttribute("aria-selected", isActive)
    })
  }

  #isValidTab(tab) {
    return this.panelTargets.some(panel => panel.dataset.tab === tab)
  }

  #persistActiveTab() {
    if (!this.storageKeyValue) return

    try {
      sessionStorage.setItem(this.storageKeyValue, this.#activeTab)
    } catch (_error) {
      // Ignore storage failures so tabs still work without persistence.
    }
  }

  #readStoredTab() {
    if (!this.storageKeyValue) return null

    try {
      return sessionStorage.getItem(this.storageKeyValue)
    } catch (_error) {
      return null
    }
  }
}
