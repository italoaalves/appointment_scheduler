import { Controller } from "@hotwired/stimulus"

// Class sets toggled on tab buttons by #render()
const TAB_ACTIVE_CLASSES   = ["border-slate-900", "text-slate-900"]
const TAB_INACTIVE_CLASSES = ["border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-700"]

export default class extends Controller {
  static targets = ["panel", "tab", "scrollArea", "stats"]

  #activeTab = "today"

  connect() {
    this.#render()
  }

  switchTab(event) {
    const tab = event.params.tab
    if (tab === this.#activeTab) return

    this.#activeTab = tab
    this.#render()

    if (this.hasScrollAreaTarget) {
      this.scrollAreaTarget.scrollTop = 0
    }
  }

  #render() {
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.tab !== this.#activeTab
    })

    this.statsTargets.forEach(stats => {
      stats.hidden = stats.dataset.tab !== this.#activeTab
    })

    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.calendarTabsTabParam === this.#activeTab
      tab.classList.remove(...TAB_ACTIVE_CLASSES, ...TAB_INACTIVE_CLASSES)
      tab.classList.add(...(isActive ? TAB_ACTIVE_CLASSES : TAB_INACTIVE_CLASSES))
    })
  }
}
