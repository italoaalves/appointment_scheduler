import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    this.setupAutoSubmit()
  }

  setupAutoSubmit() {
    // Auto-submit on select change
    this.formTarget.querySelectorAll("select").forEach(el => {
      el.addEventListener("change", () => this.submit())
    })

    // Auto-submit on checkbox change
    this.formTarget.querySelectorAll('input[type="checkbox"]').forEach(el => {
      el.addEventListener("change", () => this.submit())
    })

    // Auto-submit on date change
    this.formTarget.querySelectorAll('input[type="date"]').forEach(el => {
      el.addEventListener("change", () => this.submit())
    })

    // Submit on enter key for text inputs
    this.formTarget.querySelectorAll('input[type="text"]').forEach(el => {
      el.addEventListener("keypress", (e) => {
        if (e.key === "Enter") {
          this.submit()
        }
      })
    })

    // Submit on blur for text inputs
    this.formTarget.querySelectorAll('input[type="text"]').forEach(el => {
      el.addEventListener("blur", () => this.submit())
    })
  }

  submit() {
    this.formTarget.requestSubmit()
  }
}
