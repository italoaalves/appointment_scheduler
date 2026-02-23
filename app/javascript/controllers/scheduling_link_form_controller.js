import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["expiresField"]

  toggleExpires() {
    const select = this.element.querySelector("select")
    const field = this.expiresFieldTarget
    if (select.value === "single_use") {
      field.classList.remove("hidden")
    } else {
      field.classList.add("hidden")
    }
  }
}
