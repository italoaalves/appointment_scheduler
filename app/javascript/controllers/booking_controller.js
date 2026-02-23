import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateInput", "slotsList", "slotsContainer", "scheduledAt", "submitBtn", "slotTemplate"]

  connect() {
    this.loadSlots()
  }

  loadSlots() {
    const dateInput = this.dateInputTarget
    if (!dateInput || !dateInput.value) return

    const date = dateInput.value
    const token = window.location.pathname.split("/")[2]

    this.slotsContainerTarget.querySelector("p").textContent = this.slotsContainerTarget.dataset.loadingText || "Loading..."
    this.slotsListTarget.innerHTML = ""

    fetch(`/book/${token}/slots?from=${date}&to=${date}`)
      .then(r => r.json())
      .then(slots => {
        this.slotsContainerTarget.querySelector("p").textContent = slots.length === 0
          ? (this.slotsContainerTarget.dataset.emptyText || "No available slots for this date.")
          : (this.slotsContainerTarget.dataset.chooseText || "Choose a time:")
        this.slotsListTarget.innerHTML = ""
        slots.forEach(slot => {
          const btn = document.createElement("button")
          btn.type = "button"
          btn.className = "rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:border-slate-400 slot-btn"
          btn.dataset.slotValue = slot.value
          btn.dataset.slotLabel = slot.label
          btn.textContent = slot.label.split(" at ").pop() || slot.label
          btn.addEventListener("click", () => this.selectSlot(btn))
          this.slotsListTarget.appendChild(btn)
        })
      })
      .catch(() => {
        this.slotsContainerTarget.querySelector("p").textContent = "Unable to load slots."
      })
  }

  selectSlot(btn) {
    this.slotsListTarget.querySelectorAll(".slot-btn").forEach(b => {
      b.classList.remove("ring-2", "ring-slate-900", "border-slate-900")
    })
    btn.classList.add("ring-2", "ring-slate-900", "border-slate-900")
    this.scheduledAtTarget.value = btn.dataset.slotValue
    this.submitBtnTarget.disabled = false
  }
}
