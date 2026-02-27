import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { dismissUrl: String }

  async dismissWelcome() {
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
    }
  }
}
