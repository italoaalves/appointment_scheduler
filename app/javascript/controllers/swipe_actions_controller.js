import { Controller } from "@hotwired/stimulus"

const CLOSE_EVENT = "swipe-actions:close-others"
const HOVER_MEDIA = "(hover: hover) and (pointer: fine)"
// Minimum px of movement before we decide horizontal vs vertical
const DIRECTION_LOCK_PX = 6
// Horizontal must exceed vertical by this ratio to be treated as a swipe
const DIRECTION_LOCK_RATIO = 1.5
// Swipe distance (px) needed to trigger reveal — independent of panel width
const SWIPE_THRESHOLD = 40
// Stagger delay (ms) between each action button entrance
const STAGGER_MS = 30

export default class extends Controller {
  static targets = ["content", "actions", "hint"]

  get #isHoverDevice() {
    return window.matchMedia(HOVER_MEDIA).matches
  }

  // Touch: slide from right (X). Hover: slide from bottom (Y).
  get #hiddenTranslate() {
    return this.#isHoverDevice ? "0 100%" : "100%"
  }

  connect() {
    this.startX = 0
    this.startY = 0
    this.swiped = false
    this.directionLocked = null // null | "horizontal" | "vertical"

    // Set initial hidden state — touch: slide right, hover: slide down
    if (this.hasActionsTarget) {
      this.actionsTarget.style.translate = this.#hiddenTranslate
    }

    // Let the browser handle vertical scrolling natively at compositor level;
    // we intercept only horizontal touches.
    this.element.style.touchAction = "pan-y"

    this.onTouchStart = this.#touchStart.bind(this)
    this.onTouchMove = this.#touchMove.bind(this)
    this.onTouchEnd = this.#touchEnd.bind(this)
    this.onCloseOthers = (e) => { if (e.detail !== this) this.#reset() }
    this.onDocTap = this.#handleDocTap.bind(this)
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
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.onTouchStart)
    this.element.removeEventListener("touchmove", this.onTouchMove)
    this.element.removeEventListener("touchend", this.onTouchEnd)
    this.element.removeEventListener("mouseenter", this.onMouseEnter)
    this.element.removeEventListener("mouseleave", this.onMouseLeave)
    document.removeEventListener(CLOSE_EVENT, this.onCloseOthers)
    document.removeEventListener("touchstart", this.onDocTap)
  }

  #touchStart(e) {
    this.startX = e.touches[0].clientX
    this.startY = e.touches[0].clientY
    this.directionLocked = null
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
  }

  #touchEnd(e) {
    // Vertical gesture or indeterminate — nothing to do
    if (this.directionLocked !== "horizontal") return

    const delta = this.startX - (e.changedTouches?.[0]?.clientX ?? this.startX)
    if (!this.swiped && delta > SWIPE_THRESHOLD) {
      this.#reveal()
    } else if (this.swiped && delta < -SWIPE_THRESHOLD) {
      this.#reset()
    }
  }

  #handleMouseEnter() {
    if (!window.matchMedia(HOVER_MEDIA).matches) return
    this.#reveal()
  }

  #handleMouseLeave() {
    if (!window.matchMedia(HOVER_MEDIA).matches) return
    if (!this.swiped) this.#reset()
  }

  #handleDocTap(e) {
    if (this.swiped && !this.element.contains(e.target)) {
      this.#reset()
    }
  }

  #reveal() {
    document.dispatchEvent(new CustomEvent(CLOSE_EVENT, { detail: this }))
    this.swiped = true
    if (this.hasHintTarget) this.hintTarget.style.opacity = "0"

    if (this.hasActionsTarget) {
      this.actionsTarget.style.opacity = "1"
      this.actionsTarget.style.translate = "0"

      // Stagger each action button entrance
      const hover = this.#isHoverDevice
      const buttons = this.actionsTarget.querySelectorAll("[data-swipe-action]")
      buttons.forEach((btn, i) => {
        btn.style.transition = "none"
        btn.style.opacity = "0"
        btn.style.translate = hover ? "0 8px" : "8px"
        // Force reflow then animate
        requestAnimationFrame(() => {
          btn.style.transition = `opacity 200ms ease-out ${i * STAGGER_MS}ms, translate 200ms ease-out ${i * STAGGER_MS}ms`
          btn.style.opacity = "1"
          btn.style.translate = "0"
        })
      })
    }

    // Brief haptic pulse on devices that support it
    if (navigator.vibrate) navigator.vibrate(8)
  }

  #reset() {
    this.swiped = false
    if (this.hasHintTarget) this.hintTarget.style.opacity = "1"
    if (this.hasActionsTarget) {
      this.actionsTarget.style.opacity = "0"
      this.actionsTarget.style.translate = this.#hiddenTranslate

      // Reset button stagger styles
      const buttons = this.actionsTarget.querySelectorAll("[data-swipe-action]")
      buttons.forEach((btn) => {
        btn.style.transition = ""
        btn.style.opacity = ""
        btn.style.translate = ""
      })
    }
  }
}
