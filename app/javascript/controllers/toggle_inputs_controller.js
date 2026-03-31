import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  toggle(event) {
    const disabled = !event.target.checked
    this.inputTargets.forEach(el => el.disabled = disabled)
  }
}
