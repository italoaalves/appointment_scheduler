import { Controller } from "@hotwired/stimulus"

// Monitors the WhatsApp 24h session window expiry.
// When the session expires while the user is viewing the conversation,
// disables the reply form and updates the session indicator without a page reload.
export default class extends Controller {
  static targets = ["indicator", "textarea", "submit"]
  static values  = { expiresAt: String }

  connect() {
    this.#scheduleCheck()
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  // ── Private ────────────────────────────────────────────────────────────────

  #scheduleCheck() {
    if (!this.hasExpiresAtValue) return

    const expiresAt = new Date(this.expiresAtValue)
    const msUntilExpiry = expiresAt - Date.now()

    if (msUntilExpiry <= 0) {
      // Already expired on connect — ensure UI is in expired state
      this.#markExpired()
      return
    }

    // Fire exactly when the session expires, then re-check every 60s after
    this.timer = setTimeout(() => {
      this.#markExpired()
    }, msUntilExpiry)
  }

  #markExpired() {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.dataset.sessionTimerState = "expired"
    }

    if (this.hasTextareaTarget) {
      this.textareaTarget.disabled = true
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }
}
