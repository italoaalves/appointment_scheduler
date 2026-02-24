import { Controller } from "@hotwired/stimulus"

// Manages timezone select: when "Other" is chosen, shows text field for custom IANA identifier
export default class extends Controller {
  static targets = ["select", "input", "otherField"]

  connect() {
    this.syncFromSelect()
    this.selectTarget.addEventListener("change", () => this.syncFromSelect())
    if (this.hasOtherFieldTarget) {
      this.otherFieldTarget.addEventListener("input", () => this.syncFromOther())
    }
  }

  syncFromSelect() {
    const value = this.selectTarget.value
    if (value === this.otherValue) {
      this.showOther()
      this.inputTarget.value = this.otherFieldTarget?.value || ""
    } else {
      this.hideOther()
      this.inputTarget.value = value
    }
  }

  syncFromOther() {
    if (this.selectTarget.value === this.otherValue) {
      this.inputTarget.value = this.otherFieldTarget.value
    }
  }

  showOther() {
    if (this.hasOtherFieldTarget) {
      this.otherFieldTarget.classList.remove("hidden")
      this.otherFieldTarget.focus()
    }
  }

  hideOther() {
    if (this.hasOtherFieldTarget) {
      this.otherFieldTarget.classList.add("hidden")
    }
  }

  get otherValue() {
    return this.selectTarget.querySelector('option[value="__other__"]')?.value || "__other__"
  }
}
