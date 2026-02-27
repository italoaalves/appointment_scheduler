import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = ["dateInput", "slotsList", "slotsContainer", "scheduledAt", "submitBtn", "slotTemplate", "errorTemplate"]

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
    const container = this.slotsContainerTarget

    container.querySelector("p").textContent = container.dataset.loadingText || "Loading..."
    this.slotsListTarget.innerHTML = ""

    fetch(`${slotsUrl}?from=${date}&to=${date}`)
      .then(r => {
        if (!r.ok) throw new Error("fetch failed")
        return r.json()
      })
      .then(slots => {
        container.querySelector("p").textContent = slots.length === 0
          ? (container.dataset.emptyText || "No available slots for this date.")
          : (container.dataset.chooseText || "Choose a time:")
        this.slotsListTarget.innerHTML = ""
        slots.forEach(slot => {
          const btn = this.slotTemplateTarget.content.cloneNode(true).querySelector("button")
          btn.dataset.slotValue = slot.value
          btn.dataset.slotLabel = slot.label
          btn.textContent = slot.label.split(" at ").pop() || slot.label
          btn.addEventListener("click", () => this.selectSlot(btn))
          this.slotsListTarget.appendChild(btn)
        })
      })
      .catch(() => this.showError())
  }

  showError() {
    const container = this.slotsContainerTarget
    const error = this.errorTemplateTarget.content.cloneNode(true)
    const p = error.querySelector("p")
    const retryBtn = error.querySelector("button")
    p.textContent = container.dataset.errorText || "Could not load available times."
    retryBtn.textContent = container.dataset.retryText || "Try again"
    retryBtn.addEventListener("click", () => this.loadSlots())
    container.querySelector("p").textContent = ""
    this.slotsListTarget.innerHTML = ""
    this.slotsListTarget.appendChild(error)
  }

  selectSlot(btn) {
    this.slotsListTarget.querySelectorAll(".slot-btn").forEach(b => b.classList.remove("slot-btn-selected"))
    btn.classList.add("slot-btn-selected")
    this.scheduledAtTarget.value = btn.dataset.slotValue
    this.submitBtnTarget.disabled = false
  }
}
