import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 5000 } }

  connect() {
    this.poll()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()

      if (data.status === "completed") {
        window.location.href = this.element.dataset.successUrl
        return
      }

      if (data.status === "failed") {
        window.location.href = this.element.dataset.failureUrl
        return
      }
    } catch (e) {
      // Silently retry on network errors
    }

    this.timer = setTimeout(() => this.poll(), this.intervalValue)
  }
}
