import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  static targets = ["source", "feedback"]

  copy(event) {
    const text = this.hasSourceTarget ? this.sourceTarget.textContent.trim() : this.textValue
    if (!navigator.clipboard || !text) return

    const btn = event?.target?.closest?.("button") || this.element.querySelector('button[data-action*="clipboard#copy"]') || this.element
    const duration = this.hasFeedbackTarget ? 2000 : 1500
    const successClasses = [ "!bg-emerald-100", "!text-emerald-700" ]

    navigator.clipboard.writeText(text).then(() => {
      successClasses.forEach((c) => btn.classList.add(c))
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.classList.remove("hidden")
      } else {
        btn.dataset.origText = btn.textContent
        btn.textContent = btn.dataset.copiedText || "Copied!"
      }
      setTimeout(() => {
        successClasses.forEach((c) => btn.classList.remove(c))
        if (!this.hasFeedbackTarget && btn.dataset.origText) {
          btn.textContent = btn.dataset.origText
          delete btn.dataset.origText
        }
        if (this.hasFeedbackTarget) this.feedbackTarget.classList.add("hidden")
      }, duration)
    })
  }
}
