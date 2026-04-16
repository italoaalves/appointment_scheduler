import { Controller } from "@hotwired/stimulus"

// Manages a form modal injected into a <turbo-frame> via Turbo Frame navigation.
// Entry: fades in overlay + slides panel up (mirrors error_modal_controller).
// Exit: fades out, then clears the turbo-frame content.
// Auto-closes on successful form submission via turbo:submit-end.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this._previousFocus = document.activeElement

    this.element.style.opacity = "0"
    if (this.hasPanelTarget) this.panelTarget.style.translate = "0 20px"

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.style.transition = "opacity 200ms cubic-bezier(0.4, 0, 0.2, 1)"
        this.element.style.opacity = "1"
        if (this.hasPanelTarget) {
          this.panelTarget.style.transition = "translate 250ms cubic-bezier(0.4, 0, 0.2, 1)"
          this.panelTarget.style.translate = "0"
        }
      })
    })

    setTimeout(() => {
      this.element.querySelector("input:not([type=hidden]), textarea, select")?.focus()
    }, 260)
  }

  close() {
    this.element.style.transition = "opacity 150ms cubic-bezier(0.4, 0, 0.2, 1)"
    this.element.style.opacity = "0"
    this.element.addEventListener("transitionend", () => {
      const frame = this.element.closest("turbo-frame")
      if (frame) frame.innerHTML = ""
      this._previousFocus?.focus()
    }, { once: true })
  }

  submitEnd({ detail: { success } }) {
    if (success) this.close()
  }

  disconnect() {
    this._previousFocus?.focus()
  }
}
