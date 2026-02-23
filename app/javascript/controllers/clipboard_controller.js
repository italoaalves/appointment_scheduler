import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    const text = this.textValue
    if (navigator.clipboard && text) {
      navigator.clipboard.writeText(text).then(() => {
        const btn = this.element
        const orig = btn.textContent
        btn.textContent = btn.dataset.copiedText || "Copied!"
        setTimeout(() => { btn.textContent = orig }, 1500)
      })
    }
  }
}
