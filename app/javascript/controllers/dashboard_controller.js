import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { dismissUrl: String }

  async dismissWelcome() {
    const btn = this.element.querySelector('[data-action*="dashboard#dismissWelcome"]')
    if (btn) {
      btn.disabled = true
      btn.classList.add("opacity-50", "cursor-not-allowed")
    }

    try {
      const url = this.dismissUrlValue || "/dashboard/dismiss_welcome"
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const res = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": token,
          "Accept": "application/json",
          "Content-Type": "application/json"
        }
      })
      if (res.ok) {
        this.element.remove()
      } else {
        throw new Error("dismiss failed")
      }
    } catch {
      if (btn) {
        btn.disabled = false
        btn.classList.remove("opacity-50", "cursor-not-allowed")
      }
    }
  }
}
