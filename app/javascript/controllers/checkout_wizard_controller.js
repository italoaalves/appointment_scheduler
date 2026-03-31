import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step1", "step2", "planInput", "paidSection"]
  static values = { prices: Object }

  pick(event) {
    const slug = event.params.slug
    this.planInputTarget.value = slug
    const isPaid = (this.pricesValue[slug] || 0) > 0
    this.paidSectionTargets.forEach(el => el.classList.toggle("hidden", !isPaid))
    this.step1Target.classList.add("hidden")
    this.step2Target.classList.remove("hidden")
  }

  back() {
    this.step2Target.classList.add("hidden")
    this.step1Target.classList.remove("hidden")
  }
}
