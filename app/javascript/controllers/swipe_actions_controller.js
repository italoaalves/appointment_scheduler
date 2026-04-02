import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "actions"]

  connect() {
    this.startX = 0
    this.baseOffset = 0
    this.swiped = false
    this.REVEAL_WIDTH = 128 // matches w-32 (8rem = 128px)
    this.THRESHOLD = 60

    this.onTouchStart = this.#touchStart.bind(this)
    this.onTouchMove = this.#touchMove.bind(this)
    this.onTouchEnd = this.#touchEnd.bind(this)

    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.onTouchMove, { passive: true })
    this.element.addEventListener("touchend", this.onTouchEnd)
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchmove", this.onTouchMove)
    this.element.removeEventListener("touchend", this.onTouchEnd)
  }

  #touchStart(e) {
    this.startX = e.touches[0].clientX
    this.baseOffset = this.swiped ? -this.REVEAL_WIDTH : 0
    if (this.hasContentTarget) {
      this.contentTarget.style.transition = "none"
    }
  }

  #touchMove(e) {
    const delta = e.touches[0].clientX - this.startX + this.baseOffset
    const clamped = Math.max(-this.REVEAL_WIDTH, Math.min(0, delta))
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(${clamped}px)`
    }
  }

  #touchEnd(e) {
    const delta = e.changedTouches[0].clientX - this.startX + this.baseOffset
    if (this.hasContentTarget) {
      this.contentTarget.style.transition = ""
    }
    if (delta < -this.THRESHOLD) {
      this.#reveal()
    } else {
      this.#reset()
    }
  }

  #reveal() {
    this.swiped = true
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(-${this.REVEAL_WIDTH}px)`
    }
    if (this.hasActionsTarget) {
      this.actionsTarget.classList.remove("opacity-0")
      this.actionsTarget.classList.add("opacity-100")
    }
  }

  #reset() {
    this.swiped = false
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "translateX(0)"
    }
    if (this.hasActionsTarget) {
      this.actionsTarget.classList.add("opacity-0")
      this.actionsTarget.classList.remove("opacity-100")
    }
  }
}
