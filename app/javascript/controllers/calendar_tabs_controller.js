import { Controller } from "@hotwired/stimulus"

// Class sets toggled on tab buttons by #render()
const TAB_ACTIVE_CLASSES   = ["border-slate-900", "text-slate-900"]
const TAB_INACTIVE_CLASSES = ["border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-700"]

export default class extends Controller {
  static targets = ["panel", "tab", "scrollArea", "fadeOverlay", "stats"]

  #activeTab = "today"
  #observer  = null

  connect() {
    this.#render()
    this.#checkOverflow()

    if (this.hasScrollAreaTarget) {
      this.#observer = new ResizeObserver(() => this.#checkOverflow())
      this.#observer.observe(this.scrollAreaTarget)
    }
  }

  disconnect() {
    this.#observer?.disconnect()
  }

  switchTab(event) {
    const tab = event.params.tab
    if (tab === this.#activeTab) return

    this.#activeTab = tab
    this.#render()

    if (this.hasScrollAreaTarget) {
      this.scrollAreaTarget.scrollTop = 0
      this.#checkOverflow()
    }
  }

  checkOverflow() {
    this.#checkOverflow()
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

  #checkOverflow() {
    if (!this.hasScrollAreaTarget || !this.hasFadeOverlayTarget) return

    const el       = this.scrollAreaTarget
    const scrollable = el.scrollHeight > el.clientHeight
    const atBottom   = el.scrollTop + el.clientHeight >= el.scrollHeight - 2

    this.fadeOverlayTarget.hidden = !(scrollable && !atBottom)
  }
}
