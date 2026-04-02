import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "nav_open_group"

export default class extends Controller {
  static targets = ["flyout", "sheet", "sheetOverlay"]

  connect() {
    const openGroup = sessionStorage.getItem(STORAGE_KEY)
    if (!openGroup) return

    const panel = this.flyoutTargets.find(el => el.dataset.navGroup === openGroup)
    if (panel) {
      panel.classList.remove("hidden", "opacity-0", "translate-x-2")
      panel.classList.add("opacity-100", "translate-x-0")
    }
  }

  toggle(event) {
    event.stopPropagation()
    const group = event.params.group
    const panel = this.flyoutTargets.find(el => el.dataset.navGroup === group)
    if (!panel) return

    const isOpen = !panel.classList.contains("hidden")
    this._closeFlyouts()
    if (!isOpen) {
      sessionStorage.setItem(STORAGE_KEY, group)
      panel.classList.remove("hidden")
      requestAnimationFrame(() => {
        panel.classList.remove("opacity-0", "translate-x-2")
        panel.classList.add("opacity-100", "translate-x-0")
      })
    }
  }

  closeFlyout() {
    sessionStorage.removeItem(STORAGE_KEY)
    this._closeFlyouts()
  }

  closeAll(event) {
    if (event && this.element.contains(event.target)) return
    sessionStorage.removeItem(STORAGE_KEY)
    this._closeFlyouts()
    this.closeAllSheets()
  }

  toggleSheet(event) {
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
}
