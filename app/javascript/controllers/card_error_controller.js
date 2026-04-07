import { Controller } from "@hotwired/stimulus"

// Plays a horizontal shake animation on the host element (e.g. a card) when
// the server rejects a destructive action. Self-removes from data-controller
// after the animation so the element returns to its normal state.
export default class extends Controller {
  connect() {
    // Double rAF ensures the element is fully painted before animating
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.style.animation = "card-shake 600ms cubic-bezier(0.4, 0, 0.2, 1)"
        this.element.addEventListener("animationend", this.#cleanup.bind(this), { once: true })
      })
    })
  }

  #cleanup() {
    this.element.style.animation = ""
    this.element.dataset.controller = this.element.dataset.controller
      .split(/\s+/)
      .filter(c => c !== "card-error")
      .join(" ")
  }
}
