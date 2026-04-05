import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async load({ params: { beforeDate, page, status } }) {
    const trigger = this.element.querySelector("[data-past-loader-before-date-param]")
    if (trigger) trigger.disabled = true

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("before_date", beforeDate)
    if (page) url.searchParams.set("page", page)
    if (status) url.searchParams.set("status", status)

    try {
      const response = await fetch(url.toString(), {
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else if (trigger) {
        trigger.disabled = false
      }
    } catch {
      if (trigger) trigger.disabled = false
    }
  }
}
