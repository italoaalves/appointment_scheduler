import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    if (this.hasOpenIconTarget) {
      this.openIconTarget.classList.toggle("hidden")
      this.closeIconTarget.classList.toggle("hidden")
    }
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
      if (this.hasOpenIconTarget) {
        this.openIconTarget.classList.remove("hidden")
        this.closeIconTarget.classList.add("hidden")
      }
    }
  }
}
