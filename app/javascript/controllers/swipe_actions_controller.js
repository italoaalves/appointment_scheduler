import { Controller } from "@hotwired/stimulus"

const CLOSE_EVENT = "swipe-actions:close-others"
const HOVER_MEDIA = "(hover: hover) and (pointer: fine)"

export default class extends Controller {
  static targets = ["content", "actions"]

  connect() {
    this.startX = 0
    this.baseOffset = 0
    this.swiped = false
    this.REVEAL_WIDTH = (this.hasActionsTarget && this.actionsTarget.offsetWidth) || 80
    this.THRESHOLD = this.REVEAL_WIDTH * 0.5

    this.onTouchStart = this.#touchStart.bind(this)
    this.onTouchMove = this.#touchMove.bind(this)
    this.onTouchEnd = this.#touchEnd.bind(this)
    this.onCloseOthers = (e) => { if (e.detail !== this) this.#reset() }
    this.onDocTap = this.#handleDocTap.bind(this)
    this.onResize = this.#handleResize.bind(this)
    this.onMouseEnter = this.#handleMouseEnter.bind(this)
    this.onMouseLeave = this.#handleMouseLeave.bind(this)

    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.onTouchMove, { passive: true })
    this.element.addEventListener("touchend", this.onTouchEnd)
    this.element.addEventListener("mouseenter", this.onMouseEnter)
    this.element.addEventListener("mouseleave", this.onMouseLeave)
    document.addEventListener(CLOSE_EVENT, this.onCloseOthers)
    document.addEventListener("touchstart", this.onDocTap, { passive: true })
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchmove", this.onTouchMove)
    this.element.removeEventListener("touchend", this.onTouchEnd)
    this.element.removeEventListener("mouseenter", this.onMouseEnter)
    this.element.removeEventListener("mouseleave", this.onMouseLeave)
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

  #handleMouseEnter() {
    if (!window.matchMedia(HOVER_MEDIA).matches) return
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(-${this.REVEAL_WIDTH}px)`
    }
    if (this.hasActionsTarget) {
      this.actionsTarget.style.opacity = "1"
    }
  }

  #handleMouseLeave() {
    if (!window.matchMedia(HOVER_MEDIA).matches) return
    if (!this.swiped) {
      if (this.hasContentTarget) {
        this.contentTarget.style.transform = "translateX(0)"
      }
      if (this.hasActionsTarget) {
        this.actionsTarget.style.opacity = "0"
      }
    }
  }

  #handleDocTap(e) {
    if (this.swiped && !this.element.contains(e.target)) {
      this.#reset()
    }
  }

  #handleResize() {
    this.REVEAL_WIDTH = (this.hasActionsTarget && this.actionsTarget.offsetWidth) || 80
    this.THRESHOLD = this.REVEAL_WIDTH * 0.5
    if (this.swiped) this.#reset()
  }

  #reveal() {
    document.dispatchEvent(new CustomEvent(CLOSE_EVENT, { detail: this }))
    this.swiped = true
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(-${this.REVEAL_WIDTH}px)`
    }
    if (this.hasActionsTarget) {
      this.actionsTarget.style.opacity = "1"
    }
  }

  #reset() {
    this.swiped = false
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "translateX(0)"
    }
    if (this.hasActionsTarget) {
      this.actionsTarget.style.opacity = "0"
    }
  }
}
