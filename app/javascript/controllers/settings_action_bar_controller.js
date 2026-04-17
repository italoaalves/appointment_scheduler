import { Controller } from "@hotwired/stimulus"

const FEEDBACK_TTL_MS = 10_000
const SUCCESS_HIDE_DELAY_MS = 2_200

export default class extends Controller {
  static targets = ["panel", "status", "hint"]
  static values = {
    revealMode: String,
    successMessage: String,
    errorMessage: String
  }

  connect() {
    this.form = this.element.closest("form")
    this.feedbackKey = this.form ? `settings-action-bar:${this.#normalizePath(this.form.action)}` : null
    this.handleInput = this.handleInput.bind(this)
    this.handleReset = this.handleReset.bind(this)
    this.handleSubmitStart = this.handleSubmitStart.bind(this)
    this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.hideTimer = null
    this.lastVisibility = !this.element.classList.contains("hidden")

    if (!this.form || !this.#dirtyMode) {
      this.show()
      this.consumeFeedback()
      return
    }

    this.captureInitialState()
    this.bindFormEvents()

    if (!this.consumeFeedback() && this.hasErrors()) {
      this.show()
      this.showStatus("error")
      return
    }

    this.syncVisibility()
  }

  disconnect() {
    this.unbindFormEvents()
    this.clearHideTimer()
  }

  handleInput() {
    if (!this.#dirtyMode) return

    this.clearStatus()
    this.syncVisibility()
  }

  handleReset() {
    if (!this.#dirtyMode) return

    requestAnimationFrame(() => {
      this.captureInitialState()
      this.clearStatus()
      this.syncVisibility()
    })
  }

  handleSubmitStart() {
    this.clearHideTimer()
    this.show()
    this.clearStatus()
  }

  handleSubmitEnd(event) {
    const successful = Boolean(event.detail.success)

    this.storeFeedback(successful ? "success" : "error")

    if (!successful) {
      this.show()
      this.showStatus("error")
    }
  }

  bindFormEvents() {
    this.form.addEventListener("input", this.handleInput)
    this.form.addEventListener("change", this.handleInput)
    this.form.addEventListener("reset", this.handleReset)
    this.form.addEventListener("turbo:submit-start", this.handleSubmitStart)
    this.form.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  unbindFormEvents() {
    if (!this.form) return

    this.form.removeEventListener("input", this.handleInput)
    this.form.removeEventListener("change", this.handleInput)
    this.form.removeEventListener("reset", this.handleReset)
    this.form.removeEventListener("turbo:submit-start", this.handleSubmitStart)
    this.form.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  captureInitialState() {
    this.initialState = this.currentState()
  }

  currentState() {
    return this.editableFields().map((field) => this.serializeField(field)).join("||")
  }

  editableFields() {
    if (!this.form) return []

    return [...this.form.querySelectorAll("input, select, textarea")]
      .filter((field) => {
        if (field.disabled || field.closest("[hidden]")) return false

        if (field.tagName === "INPUT") {
          return !["hidden", "submit", "button", "reset"].includes(field.type)
        }

        return true
      })
  }

  serializeField(field) {
    const identifier = `${field.name || field.id || "field"}`

    if (field.tagName === "INPUT" && field.type === "file") {
      const files = [...field.files].map((file) => file.name).join(",")
      return `${identifier}:${files}`
    }

    if (field.tagName === "INPUT" && ["checkbox", "radio"].includes(field.type)) {
      return `${identifier}:${field.value}:${field.checked}`
    }

    return `${identifier}:${field.value}`
  }

  syncVisibility() {
    if (!this.#dirtyMode) {
      this.show()
      return
    }

    if (this.isDirty() || this.hasVisibleStatus()) {
      this.show()
    } else {
      this.hide()
    }
  }

  isDirty() {
    return this.currentState() !== this.initialState
  }

  hasErrors() {
    if (!this.form) return false

    return Boolean(this.form.querySelector("#error_explanation"))
  }

  show() {
    this.element.classList.remove("hidden")

    if (!this.lastVisibility) {
      this.animatePanel("action-feedback 260ms cubic-bezier(0.34, 1.56, 0.64, 1)")
    }

    this.lastVisibility = true
  }

  hide() {
    if (this.hasVisibleStatus()) return

    this.element.classList.add("hidden")
    this.lastVisibility = false
  }

  showStatus(kind) {
    if (!this.hasStatusTarget) return

    const message = kind === "success" ? this.successMessageValue : this.errorMessageValue

    this.statusTarget.textContent = message
    this.statusTarget.dataset.feedbackState = kind
    this.statusTarget.classList.remove("hidden")

    if (this.hasHintTarget) {
      this.hintTarget.classList.add("md:hidden")
    }

    this.animatePanel(
      kind === "success"
        ? "action-feedback 320ms cubic-bezier(0.34, 1.56, 0.64, 1)"
        : "card-shake 380ms ease-in-out"
    )
  }

  clearStatus() {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = ""
    delete this.statusTarget.dataset.feedbackState
    this.statusTarget.classList.add("hidden")

    if (this.hasHintTarget) {
      this.hintTarget.classList.remove("md:hidden")
    }
  }

  hasVisibleStatus() {
    return this.hasStatusTarget && !this.statusTarget.classList.contains("hidden")
  }

  consumeFeedback() {
    if (!this.feedbackKey) return false

    const payload = this.readFeedback()
    if (!payload) return false

    this.show()
    this.showStatus(payload.kind)

    if (payload.kind === "success" && this.#dirtyMode) {
      this.captureInitialState()
      this.hideTimer = window.setTimeout(() => {
        this.clearStatus()
        this.syncVisibility()
      }, SUCCESS_HIDE_DELAY_MS)
    }

    return true
  }

  storeFeedback(kind) {
    if (!this.feedbackKey) return

    window.sessionStorage.setItem(this.feedbackKey, JSON.stringify({
      kind,
      timestamp: Date.now()
    }))
  }

  readFeedback() {
    if (!this.feedbackKey) return null

    const raw = window.sessionStorage.getItem(this.feedbackKey)
    if (!raw) return null

    window.sessionStorage.removeItem(this.feedbackKey)

    try {
      const payload = JSON.parse(raw)
      if (!payload.kind || (Date.now() - payload.timestamp) > FEEDBACK_TTL_MS) return null
      return payload
    } catch (_error) {
      return null
    }
  }

  clearHideTimer() {
    if (this.hideTimer) {
      window.clearTimeout(this.hideTimer)
      this.hideTimer = null
    }
  }

  animatePanel(animation) {
    if (!this.hasPanelTarget) return

    this.panelTarget.style.animation = "none"
    requestAnimationFrame(() => {
      this.panelTarget.style.animation = animation
      this.panelTarget.addEventListener("animationend", () => {
        this.panelTarget.style.animation = ""
      }, { once: true })
    })
  }

  #normalizePath(url) {
    return new URL(url, window.location.origin).pathname
  }

  get #dirtyMode() {
    return this.revealModeValue === "dirty"
  }
}
