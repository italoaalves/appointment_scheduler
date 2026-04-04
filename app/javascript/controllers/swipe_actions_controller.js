import { Controller } from "@hotwired/stimulus"

const CLOSE_EVENT = "swipe-actions:close-others"
const HOVER_MEDIA = "(hover: hover) and (pointer: fine)"
// Minimum px of movement before we decide horizontal vs vertical
const DIRECTION_LOCK_PX = 6
// Horizontal must exceed vertical by this ratio to be treated as a swipe
const DIRECTION_LOCK_RATIO = 1.5

export default class extends Controller {
  static targets = ["content", "actions"]

  connect() {
    this.startX = 0
    this.startY = 0
    this.baseOffset = 0
    this.swiped = false
    this.directionLocked = null // null | "horizontal" | "vertical"
    this.REVEAL_WIDTH = (this.hasActionsTarget && this.actionsTarget.offsetWidth) || 80
    this.THRESHOLD = this.REVEAL_WIDTH * 0.5

    // Let the browser handle vertical scrolling natively at compositor level;
    // we intercept only horizontal touches.
    this.element.style.touchAction = "pan-y"

    this.onTouchStart = this.#touchStart.bind(this)
    this.onTouchMove = this.#touchMove.bind(this)
    this.onTouchEnd = this.#touchEnd.bind(this)
    this.onCloseOthers = (e) => { if (e.detail !== this) this.#reset() }
    this.onDocTap = this.#handleDocTap.bind(this)
    this.onResize = this.#handleResize.bind(this)
    this.onMouseEnter = this.#handleMouseEnter.bind(this)
    this.onMouseLeave = this.#handleMouseLeave.bind(this)

    this.element.addEventListener("touchstart", this.onTouchStart, { passive: true })
    // Non-passive so we can call preventDefault() to block page scroll during horizontal swipes
    this.element.addEventListener("touchmove", this.onTouchMove, { passive: false })
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
    this.startY = e.touches[0].clientY
    this.baseOffset = this.swiped ? -this.REVEAL_WIDTH : 0
    this.directionLocked = null
    if (this.hasContentTarget) {
      this.contentTarget.style.transition = "none"
    }
  }

  #touchMove(e) {
    const deltaX = e.touches[0].clientX - this.startX
    const deltaY = e.touches[0].clientY - this.startY
    const absX = Math.abs(deltaX)
    const absY = Math.abs(deltaY)

    // Lock direction once the finger has moved enough to be intentional
    if (this.directionLocked === null && (absX > DIRECTION_LOCK_PX || absY > DIRECTION_LOCK_PX)) {
      this.directionLocked = absX > absY * DIRECTION_LOCK_RATIO ? "horizontal" : "vertical"
    }

    if (this.directionLocked !== "horizontal") return

    // Block page scroll while we handle the horizontal swipe
    e.preventDefault()

    const delta = deltaX + this.baseOffset
    const clamped = Math.max(-this.REVEAL_WIDTH, Math.min(0, delta))
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = `translateX(${clamped}px)`
    }
  }

  #touchEnd(e) {
    if (this.hasContentTarget) {
      this.contentTarget.style.transition = ""
    }

    // Vertical gesture or indeterminate — snap back without animating a state change
    if (this.directionLocked !== "horizontal") {
      if (this.swiped) {
        // Card was already open; keep it open rather than snapping on a vertical tap
        if (this.hasContentTarget) {
          this.contentTarget.style.transform = `translateX(-${this.REVEAL_WIDTH}px)`
        }
      }
      return
    }

    const delta = e.changedTouches[0].clientX - this.startX + this.baseOffset
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
    // Brief haptic pulse on devices that support it
    if (navigator.vibrate) navigator.vibrate(8)
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
