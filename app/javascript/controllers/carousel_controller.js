import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = { interval: { type: Number, default: 4000 }, current: { type: Number, default: 0 } }

  connect() {
    if (this.slideTargets.length > 1) {
      this.start()
    }
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
  }

  next() {
    this.currentValue = (this.currentValue + 1) % this.slideTargets.length
  }

  goTo(event) {
    this.stop()
    this.currentValue = parseInt(event.currentTarget.dataset.index)
    this.start()
  }

  currentValueChanged(index) {
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== index)
    })
    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("opacity-30", i !== index)
      dot.classList.toggle("opacity-100", i === index)
    })
  }
}
