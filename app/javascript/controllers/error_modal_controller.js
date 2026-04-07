import { Controller } from "@hotwired/stimulus"

// Manages the lifecycle of an error modal injected via Turbo Stream.
// Entry: fades in overlay + slides panel up.
// Exit: fades out, then removes the overlay element from the DOM.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this._previousFocus = document.activeElement

    this.element.style.opacity = "0"
    if (this.hasPanelTarget) {
      this.panelTarget.style.translate = "0 20px"
    }

    // Two rAFs: first lands the element in the DOM, second starts the transition
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.style.transition = "opacity 200ms cubic-bezier(0.4, 0, 0.2, 1)"
        this.element.style.opacity = "1"
        if (this.hasPanelTarget) {
          this.panelTarget.style.transition = "translate 250ms cubic-bezier(0.4, 0, 0.2, 1)"
          this.panelTarget.style.translate = "0 0"
        }
      })
    })

    // Move focus to the dismiss button after the enter animation
    setTimeout(() => {
      this.element.querySelector("[data-error-modal-dismiss]")?.focus()
    }, 260)
  }

  close() {
    this.element.style.transition = "opacity 150ms cubic-bezier(0.4, 0, 0.2, 1)"
    this.element.style.opacity = "0"
    this.element.addEventListener("transitionend", () => {
      this.element.remove()
      this._previousFocus?.focus()
    }, { once: true })
  }

  disconnect() {
    this._previousFocus?.focus()
  }
}
