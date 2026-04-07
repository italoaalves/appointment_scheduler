import { Controller } from "@hotwired/stimulus"

// Dynamically computes `top` for sticky-section elements based on the
// actual rendered height of the sticky-filter above them.  This replaces
// the fixed CSS custom-property approach that broke when filter content
// wrapped on smaller viewports.
//
// Usage:
//   <div data-controller="sticky-stack">
//     <form class="sticky-filter" data-sticky-stack-target="filter">…</form>
//     <div class="sticky-section" data-sticky-stack-target="section">…</div>
//   </div>
export default class extends Controller {
  static targets = ["filter", "section"]

  initialize() {
    this.observer = new ResizeObserver(() => this.recalculate())
  }

  connect() {
    this.filterTargets.forEach((el) => this.observer.observe(el))
    this.recalculate()
  }

  disconnect() {
    this.observer.disconnect()
  }

  filterTargetConnected(el) {
    this.observer.observe(el)
    this.recalculate()
  }

  filterTargetDisconnected(el) {
    this.observer.unobserve(el)
    this.recalculate()
  }

  sectionTargetConnected() {
    this.recalculate()
  }

  recalculate() {
    if (!this.hasFilterTarget) return

    let stackBottom = 0

    this.filterTargets.forEach((filter) => {
      const top = parseFloat(getComputedStyle(filter).top) || 0
      stackBottom = Math.max(stackBottom, top + filter.offsetHeight)
    })

    // Use the same top offset as the filter for the gap
    const gap = parseFloat(getComputedStyle(this.filterTargets[0]).top) || 0
    const sectionTop = `${stackBottom + gap}px`

    this.sectionTargets.forEach((section) => {
      section.style.top = sectionTop
    })
  }
}
