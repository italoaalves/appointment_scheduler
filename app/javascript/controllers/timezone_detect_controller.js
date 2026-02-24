import { Controller } from "@hotwired/stimulus"

// Pre-fills the timezone field with the browser's timezone when empty
export default class extends Controller {
  connect() {
    if (this.element.value) return

    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
      if (tz) this.element.value = tz
    } catch (_) {}
  }
}
