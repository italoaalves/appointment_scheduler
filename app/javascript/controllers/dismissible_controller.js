import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { autoClose: { type: Number, default: 0 } }

  connect() {
    if (this.autoCloseValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.autoCloseValue)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.remove()
  }
}
