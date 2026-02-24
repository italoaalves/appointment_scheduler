import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = ["dateInput", "slotsList", "slotsContainer", "scheduledAt", "submitBtn", "slotTemplate"]

  connect() {
    this.initFlatpickr()
    this.loadSlots()
  }

  disconnect() {
    if (this.flatpickrInstance) this.flatpickrInstance.destroy()
  }

  static values = { slotsUrl: String, businessWeekdays: Array }

  initFlatpickr() {
    const input = this.dateInputTarget
    if (!input) return

    const min = input.min
    const max = input.max
    const businessWeekdays = this.hasBusinessWeekdaysValue ? this.businessWeekdaysValue : null
    const initialDate = input.value
    const pickerMin = min ? new Date(min + "T12:00:00") : null
    const pickerMax = max ? new Date(max + "T12:00:00") : null

    const options = {
      dateFormat: "Y-m-d",
      minDate: pickerMin,
      maxDate: pickerMax,
      defaultDate: initialDate || undefined,
      onChange: (_selectedDates, dateStr) => {
        input.value = dateStr
        this.loadSlots()
      }
    }

    if (businessWeekdays && businessWeekdays.length > 0) {
      options.disable = [
        (date) => !businessWeekdays.includes(date.getDay())
      ]
    }

    this.flatpickrInstance = flatpickr(input, options)

    if (initialDate && businessWeekdays?.length > 0) {
      const d = new Date(initialDate + "T12:00:00")
      if (!businessWeekdays.includes(d.getDay())) {
        const next = this.nextBusinessDate(d, businessWeekdays)
        if (next) {
          this.flatpickrInstance.setDate(next, false)
          input.value = next.toISOString().slice(0, 10)
          this.loadSlots()
        }
      }
    }
  }

  nextBusinessDate(from, weekdays) {
    let d = new Date(from)
    for (let i = 0; i < 14; i++) {
      if (weekdays.includes(d.getDay())) return d
      d.setDate(d.getDate() + 1)
    }
    return null
  }

  loadSlots() {
    const dateInput = this.dateInputTarget
    if (!dateInput || !dateInput.value) return

    const date = dateInput.value
    const slotsUrl = this.hasSlotsUrlValue ? this.slotsUrlValue : `/book/${window.location.pathname.split("/")[2]}/slots`

    this.slotsContainerTarget.querySelector("p").textContent = this.slotsContainerTarget.dataset.loadingText || "Loading..."
    this.slotsListTarget.innerHTML = ""

    fetch(`${slotsUrl}?from=${date}&to=${date}`)
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
