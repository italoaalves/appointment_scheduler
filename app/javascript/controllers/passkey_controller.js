import { Controller } from "@hotwired/stimulus"
import { parseCreationOptionsFromJSON, parseRequestOptionsFromJSON, publicKeyCredentialToJSON } from "utils/webauthn"

export default class extends Controller {
  static targets = ["button", "error", "label"]
  static values = {
    optionsUrl: String,
    submitUrl: String,
    unsupportedMessage: String,
    genericErrorMessage: String,
    labelRequiredMessage: String
  }

  async register() {
    if (!this.supported()) {
      this.showError(this.unsupportedMessageValue)
      return
    }

    const label = this.hasLabelTarget ? this.labelTarget.value.trim() : ""
    if (this.hasLabelTarget && !label) {
      this.showError(this.labelRequiredMessageValue)
      return
    }

    await this.perform("register", { label })
  }

  async authenticate() {
    if (!this.supported()) {
      this.showError(this.unsupportedMessageValue)
      return
    }

    await this.perform("authenticate")
  }

  async perform(mode, extraPayload = {}) {
    this.setBusy(true, mode)
    this.hideError()

    try {
      const options = await this.postJSON(this.optionsUrlValue)
      const publicKey =
        mode === "register" ? parseCreationOptionsFromJSON(options) : parseRequestOptionsFromJSON(options)

      const credential =
        mode === "register"
          ? await navigator.credentials.create({ publicKey })
          : await navigator.credentials.get({ publicKey })

      const payload = {
        ...extraPayload,
        public_key_credential: publicKeyCredentialToJSON(credential)
      }

      const result = await this.postJSON(this.submitUrlValue, payload)
      if (result.redirect_url && window.Turbo?.visit) {
        window.Turbo.visit(result.redirect_url)
      }
    } catch (error) {
      this.showError(error.message || this.genericErrorMessageValue)
    } finally {
      this.setBusy(false)
    }
  }

  async postJSON(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body)
    })

    const text = await response.text()
    const data = text ? JSON.parse(text) : {}

    if (!response.ok) {
      if (data.redirect_url && window.Turbo?.visit) {
        window.Turbo.visit(data.redirect_url)
      }

      throw new Error(data.error || this.genericErrorMessageValue)
    }

    return data
  }

  setBusy(busy, mode = null) {
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = busy

    if (!this.buttonTarget.dataset.originalText) {
      this.buttonTarget.dataset.originalText = this.buttonTarget.textContent.trim()
    }

    if (busy) {
      const loadingText =
        mode === "register" ? this.buttonTarget.dataset.registerLoadingText : this.buttonTarget.dataset.authenticateLoadingText
      this.buttonTarget.textContent = loadingText || this.buttonTarget.dataset.originalText
      return
    }

    this.buttonTarget.textContent = this.buttonTarget.dataset.originalText
  }

  showError(message) {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  supported() {
    return typeof window.PublicKeyCredential !== "undefined" && !!navigator.credentials
  }
}
