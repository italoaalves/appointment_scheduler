import { Controller } from "@hotwired/stimulus"

// Plays a brief "success pop" animation on connect, then self-removes from
// data-controller. Attached by turbo stream responses to acknowledge in-place
// state changes (confirm, cancel, etc.) without a flash message.
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.style.animation = "action-feedback 340ms cubic-bezier(0.34, 1.56, 0.64, 1)"
        this.element.addEventListener("animationend", this.#cleanup.bind(this), { once: true })
      })
    })
  }

  #cleanup() {
    this.element.style.animation = ""
    this.element.dataset.controller = (this.element.dataset.controller || "")
      .split(/\s+/)
      .filter(c => c !== "action-feedback")
      .join(" ")
      .trim()
  }
}
