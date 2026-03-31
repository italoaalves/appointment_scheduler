import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "target", "hiddenField"]
  static values = { showWhen: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const match = this.sourceTarget.value === this.showWhenValue
    this.targetTargets.forEach(el => el.classList.toggle("hidden", !match))
    this.#syncHiddenField()
  }

  syncFromTarget() {
    this.#syncHiddenField()
  }

  #syncHiddenField() {
    if (!this.hasHiddenFieldTarget) return
    const match = this.sourceTarget.value === this.showWhenValue
    this.hiddenFieldTarget.value = match
      ? this.targetTargets[0]?.value || ""
      : this.sourceTarget.value
  }
}
