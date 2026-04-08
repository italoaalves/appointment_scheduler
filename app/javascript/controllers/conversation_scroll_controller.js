import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.scrollReady = "false"
    this._scheduleScrollToBottom()
  }

  disconnect() {
    if (this._frameOne) cancelAnimationFrame(this._frameOne)
    if (this._frameTwo) cancelAnimationFrame(this._frameTwo)
  }

  _scheduleScrollToBottom() {
    this._frameOne = requestAnimationFrame(() => {
      this._frameTwo = requestAnimationFrame(() => {
        this.element.scrollTop = this.element.scrollHeight
        this.element.dataset.scrollReady = "true"
      })
    })
  }
}
