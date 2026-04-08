import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.toggle("hidden")
  }

  close() {
    if (this.hasPanelTarget) this.panelTarget.classList.add("hidden")
  }
}
