import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { cardSelector: { type: String, default: ".appointment-card" } }

  connect() {
    this.cardHeights = new WeakMap()

    this.unloadObserver = new IntersectionObserver(
      (entries) => this.#handleVisibility(entries),
      { rootMargin: "400px 0px 400px 0px" }
    )

    this.#observeCards()

    this.element.addEventListener("turbo:frame-load", () => this.#observeCards())
  }

  disconnect() {
    this.unloadObserver.disconnect()
  }

  #observeCards() {
    this.element.querySelectorAll(this.cardSelectorValue).forEach((card) => {
      if (!card.dataset.observed) {
        card.dataset.observed = "1"
        this.unloadObserver.observe(card)
      }
    })
  }

  #handleVisibility(entries) {
    entries.forEach((entry) => {
      const card = entry.target
      if (!entry.isIntersecting) {
        if (!this.cardHeights.has(card)) {
          this.cardHeights.set(card, card.offsetHeight)
        }
        card.style.minHeight = `${this.cardHeights.get(card)}px`
        card.classList.add("is-unloaded")
      } else {
        card.classList.remove("is-unloaded")
        card.style.minHeight = ""
      }
    })
  }
}
