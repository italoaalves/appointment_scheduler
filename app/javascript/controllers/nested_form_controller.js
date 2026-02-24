import { Controller } from "@hotwired/stimulus"

// Adds/removes nested form entries (e.g. availability exceptions)
export default class extends Controller {
  static values = {
    wrapper: { type: String, default: ".nested-fields" }
  }

  static targets = [ "template", "container" ]

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".exception-fields") || event.target.closest(this.wrapperValue)
    if (!wrapper) return

    const destroyInput = wrapper.querySelector("input[name*='[_destroy]']")
    if (destroyInput) {
      destroyInput.value = "1"
      wrapper.style.display = "none"
    } else {
      wrapper.remove()
    }
  }
}
