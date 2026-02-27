import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  static targets = ["source", "feedback"]

  copy() {
    const text = this.hasSourceTarget ? this.sourceTarget.textContent.trim() : this.textValue
    if (!navigator.clipboard || !text) return

    navigator.clipboard.writeText(text).then(() => {
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.classList.remove("hidden")
        setTimeout(() => this.feedbackTarget.classList.add("hidden"), 2000)
      } else {
        const btn = this.element
        const orig = btn.textContent
        btn.textContent = btn.dataset.copiedText || "Copied!"
        setTimeout(() => { btn.textContent = orig }, 1500)
      }
    })
  }
}
