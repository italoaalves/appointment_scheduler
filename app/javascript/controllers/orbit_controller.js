import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["circle"]

  connect() {
    this.circleTargets.forEach((el, i) => {
      const duration = 20 + i * 10
      el.style.animation = `orbit-float ${duration}s ease-in-out infinite alternate`
    })
  }
}
