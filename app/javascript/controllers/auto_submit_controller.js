import { Controller } from "@hotwired/stimulus"

// Automatically submits the form after the user stops typing.
// Only fires when the input is empty OR has at least `minLength` characters,
// so mid-word states (e.g. 1–2 chars) don't trigger a fetch.
//
// Usage:
//   <form data-controller="auto-submit" data-turbo-frame="...">
//     <input data-auto-submit-target="input"
//            data-action="input->auto-submit#search">
//   </form>
export default class extends Controller {
  static targets = ["input"]
  static values = {
    delay:     { type: Number, default: 400 },
    minLength: { type: Number, default: 3 }
  }

  #timer = null

  search() {
    clearTimeout(this.#timer)

    const length = this.inputTarget.value.length
    if (length === 0 || length >= this.minLengthValue) {
      this.#timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
    }
  }

  disconnect() {
    clearTimeout(this.#timer)
  }
}
