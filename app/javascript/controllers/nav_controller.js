import { Controller } from "@hotwired/stimulus"

// Group → path prefix mapping (mirrors nav_group_active? in UiHelper)
const GROUP_PATTERNS = {
  appointments: [/^\/$/, /^\/appointments/, /^\/scheduling_links/, /^\/personalized_scheduling_links/, /^\/customers/],
  communication: [/^\/inbox/],
  space:         [/^\/users/, /^\/settings/],
  profile:       [/^\/profile/, /^\/preferences/],
}

const ACTIVE_CLASSES   = ["bg-electric/15", "text-electric"]
const INACTIVE_CLASSES = ["text-slate-400", "hover:text-deep", "hover:bg-slate-100/60"]

export default class extends Controller {
  static targets = ["flyout", "sheet", "sheetOverlay"]

  connect() {
    this._updateActiveStates()
    this._handleTurboLoad = () => this._updateActiveStates()
    document.addEventListener("turbo:load", this._handleTurboLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this._handleTurboLoad)
  }

  toggle(event) {
    event.stopPropagation()
    const group = event.params.group
    const panel = this.flyoutTargets.find(el => el.dataset.navGroup === group)
    if (!panel) return

    const isOpen = !panel.classList.contains("hidden")
    this._closeFlyouts()
    if (!isOpen) {
      panel.classList.remove("hidden")
      requestAnimationFrame(() => {
        panel.classList.remove("opacity-0", "translate-x-2")
        panel.classList.add("opacity-100", "translate-x-0")
      })
    }
  }

  closeFlyout() {
    this._closeFlyouts()
  }

  // Handles both touchstart (mobile) and click (desktop).
  // On touchstart, preventDefault() suppresses the subsequent synthetic click
  // so the sheet is only toggled once per tap.
  toggleSheet(event) {
    if (event.type === "touchstart") {
      event.preventDefault()
    }
    event.stopPropagation()

    const group = event.params.group
    const sheet = this.sheetTargets.find(el => el.dataset.navGroup === group)
    if (!sheet) return

    const isOpen = !sheet.classList.contains("hidden")
    this.closeAllSheets()
    if (!isOpen) {
      this.sheetOverlayTarget.classList.remove("hidden")
      sheet.classList.remove("hidden")
      requestAnimationFrame(() => {
        sheet.classList.remove("translate-y-full")
        sheet.classList.add("translate-y-0")
      })
    }
  }

  closeAll(event) {
    if (event?.type === "touchstart") {
      event.preventDefault()
    }
    this._closeFlyouts()
    this.closeAllSheets()
  }

  closeAllSheets() {
    this.sheetTargets.forEach(el => {
      el.classList.add("translate-y-full")
      el.classList.remove("translate-y-0")
      setTimeout(() => el.classList.add("hidden"), 200)
    })
    if (this.hasSheetOverlayTarget) {
      this.sheetOverlayTarget.classList.add("hidden")
    }
  }

  _closeFlyouts() {
    this.flyoutTargets.forEach(el => {
      el.classList.add("hidden", "opacity-0", "translate-x-2")
      el.classList.remove("opacity-100", "translate-x-0")
    })
  }

  _updateActiveStates() {
    const path = window.location.pathname
    const buttons = this.element.querySelectorAll("[data-nav-group-param]")

    buttons.forEach(btn => {
      const group = btn.dataset.navGroupParam
      const patterns = GROUP_PATTERNS[group] || []
      const active = patterns.some(re => re.test(path))

      if (active) {
        btn.classList.add(...ACTIVE_CLASSES)
        btn.classList.remove(...INACTIVE_CLASSES)
      } else {
        btn.classList.remove(...ACTIVE_CLASSES)
        btn.classList.add(...INACTIVE_CLASSES)
      }
    })
  }
}
