import { Controller } from "@hotwired/stimulus"

const CLOSE_EVENT = "swipe-actions:close-others"

export default class extends Controller {
  static targets = ["content", "actions"]

  connect() {
    this.startX = 0
    this.baseOffset = 0
    this.swiped = false
    this.REVEAL_WIDTH = 128
    this.THRESHOLD = 60
    this.MD_BREAKPOINT = 768

    this.onTouchStart = this.#touchStart.bind(this)
    this.onTouchMove = this.#touchMove.bind(this)
    this.onTouchEnd = this.#touchEnd.bind(this)
    this.onCloseOthers = (e) => { if (e.detail !== this) this.#reset() }
    this.onDocTap = this.#handleDocTap.bind(this)
    this.onResize = this.#handleResize.bind(this)

    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.onTouchMove, { passive: true })
    this.element.addEventListener("touchend", this.onTouchEnd)
    document.addEventListener(CLOSE_EVENT, this.onCloseOthers)
    document.addEventListener("touchstart", this.onDocTap, { passive: true })
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchmove", this.onTouchMove)
    this.element.removeEventListener("touchend", this.onTouchEnd)
    document.removeEventListener(CLOSE_EVENT, this.onCloseOthers)
    document.removeEventListener("touchstart", this.onDocTap)
    window.removeEventListener("resize", this.onResize)
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

  #handleDocTap(e) {
    if (this.swiped && !this.element.contains(e.target)) {
      this.#reset()
    }
  }

  #handleResize() {
    if (this.swiped && window.innerWidth >= this.MD_BREAKPOINT) {
      this.#reset()
    }
  }

  #reveal() {
    document.dispatchEvent(new CustomEvent(CLOSE_EVENT, { detail: this }))
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
