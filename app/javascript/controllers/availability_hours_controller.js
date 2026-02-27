import { Controller } from "@hotwired/stimulus"

// Syncs simple "Open/Close + day checkboxes" UI with availability window inputs.
// Supports add-to-list overrides: user adds items like "Saturday 10:00–14:00".
export default class extends Controller {
  static targets = [ "opensAt", "closesAt", "dayCheckbox", "windowRow", "overrideTemplate", "overrideList", "overrideItem", "preview" ]
  static values = {
    defaultOpens: { type: String, default: "09:00" },
    defaultCloses: { type: String, default: "17:00" },
    weekdayAbbr: { type: Array, default: [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ] },
    everyDay: { type: String, default: "Every day" }
  }

  connect() {
    this.syncFromRows()
    const allBlank = this.windowRowTargets.every(row =>
      !row.querySelector('input[type="time"][name*="opens_at"]')?.value
    )
    if (allBlank && this.hasOpensAtTarget && this.hasClosesAtTarget) {
      this.opensAtTarget.value = this.defaultOpensValue
      this.closesAtTarget.value = this.defaultClosesValue
      this.dayCheckboxTargets.forEach(cb => {
        cb.checked = [ 1, 2, 3, 4, 5 ].includes(parseInt(cb.dataset.weekday, 10))
      })
      this.syncToRows()
    }
    this.rebuildOverridesFromRows()
    this.updatePreview()
  }

  applyPreset(e) {
    e.preventDefault()
    const days = e.currentTarget.dataset.availabilityHoursPreset.split(",").map(Number)
    this.opensAtTarget.value = this.defaultOpensValue
    this.closesAtTarget.value = this.defaultClosesValue
    this.dayCheckboxTargets.forEach(cb => {
      cb.checked = days.includes(parseInt(cb.dataset.weekday, 10))
    })
    this.syncOverrides()
    this.updatePreview()
  }

  sync() {
    this.syncOverrides()
  }

  addOverride(e) {
    e?.preventDefault()
    if (!this.hasOverrideTemplateTarget || !this.hasOverrideListTarget) return

    const defaultOpens = this.opensAtTarget?.value || this.defaultOpensValue
    const defaultCloses = this.closesAtTarget?.value || this.defaultClosesValue
    const usedDays = this.getOverrideDays()
    const weekdays = [ 0, 1, 2, 3, 4, 5, 6 ]
    const available = weekdays.filter(d => !usedDays.includes(d))

    const content = this.overrideTemplateTarget.innerHTML
    this.overrideListTarget.insertAdjacentHTML("beforeend", content)

    const newItem = this.overrideListTarget.lastElementChild
    const daySelect = newItem?.querySelector("select")
    const times = newItem?.querySelectorAll('input[type="time"]') ?? []
    const opensInput = times[0]
    const closesInput = times[1]

    if (daySelect && available.length > 0) daySelect.value = String(available[0])
    if (opensInput) opensInput.value = defaultOpens
    if (closesInput) closesInput.value = defaultCloses

    this.syncOverrides()
  }

  removeOverride(e) {
    const item = e?.target?.closest(".availability-override-item")
    if (item) this.removeOverrideFromElement(e, item)
  }

  removeOverrideFromElement(e, item) {
    e?.preventDefault()
    item?.remove()
    this.syncOverrides()
  }

  syncOverrides() {
    const defaultOpens = this.opensAtTarget?.value ?? ""
    const defaultCloses = this.closesAtTarget?.value ?? ""

    this.windowRowTargets.forEach(row => {
      const wday = parseInt(row.dataset.weekday, 10)
      const opensInput = row.querySelector('input[type="time"][name*="opens_at"]')
      const closesInput = row.querySelector('input[type="time"][name*="closes_at"]')
      if (!opensInput || !closesInput) return

      const override = this.getOverrideForDay(wday)
      const dayChecked = this.dayCheckboxTargets.find(cb => parseInt(cb.dataset.weekday, 10) === wday)?.checked

      if (override) {
        opensInput.value = override.opens
        closesInput.value = override.closes
      } else if (dayChecked && defaultOpens && defaultCloses) {
        opensInput.value = defaultOpens
        closesInput.value = defaultCloses
      } else {
        opensInput.value = ""
        closesInput.value = ""
      }
    })
    this.updatePreview()
  }

  getOverrideForDay(wday) {
    const items = this.overrideListTarget?.querySelectorAll(".availability-override-item") ?? []
    for (const item of items) {
      const daySelect = item.querySelector("select")
      const times = item.querySelectorAll('input[type="time"]')
      if (daySelect && parseInt(daySelect.value, 10) === wday && times.length >= 2) {
        const opens = times[0]?.value
        const closes = times[1]?.value
        if (opens && closes) return { opens, closes }
      }
    }
    return null
  }

  getOverrideDays() {
    const items = this.overrideListTarget?.querySelectorAll(".availability-override-item") ?? []
    return Array.from(items).map(item => {
      const s = item.querySelector("select")
      return s ? parseInt(s.value, 10) : null
    }).filter(d => d !== null && !isNaN(d))
  }

  rebuildOverridesFromRows() {
    if (!this.hasOverrideListTarget) return
    const defaultOpens = this.opensAtTarget?.value || this.defaultOpensValue
    const defaultCloses = this.closesAtTarget?.value || this.defaultClosesValue

    const differentDays = []
    this.windowRowTargets.forEach(row => {
      const wday = parseInt(row.dataset.weekday, 10)
      const opensInput = row.querySelector('input[type="time"][name*="opens_at"]')
      const closesInput = row.querySelector('input[type="time"][name*="closes_at"]')
      const opens = opensInput?.value
      const closes = closesInput?.value
      if (!opens || !closes) return
      if (opens === defaultOpens && closes === defaultCloses) return
      differentDays.push({ wday, opens, closes })
    })

    differentDays.forEach(({ wday, opens, closes }) => {
      this.addOverride()
      const lastItem = this.overrideListTarget.lastElementChild
      if (lastItem) {
        const daySelect = lastItem.querySelector("select")
        const times = lastItem.querySelectorAll('input[type="time"]')
        if (daySelect) daySelect.value = String(wday)
        if (times[0]) times[0].value = opens
        if (times[1]) times[1].value = closes
      }
    })
  }

  syncFromRows() {
    const rowsWithTimes = this.windowRowTargets.filter(
      row => row.querySelector('input[type="time"][name*="opens_at"]')?.value &&
             row.querySelector('input[type="time"][name*="closes_at"]')?.value
    )
    if (rowsWithTimes.length === 0) {
      if (this.hasOpensAtTarget) this.opensAtTarget.value = this.defaultOpensValue
      if (this.hasClosesAtTarget) this.closesAtTarget.value = this.defaultClosesValue
      return
    }
    const first = rowsWithTimes[0]
    const opens = first.querySelector('input[type="time"][name*="opens_at"]')?.value
    const closes = first.querySelector('input[type="time"][name*="closes_at"]')?.value
    if (opens && this.hasOpensAtTarget) this.opensAtTarget.value = opens
    if (closes && this.hasClosesAtTarget) this.closesAtTarget.value = closes
    this.dayCheckboxTargets.forEach(cb => {
      const wday = parseInt(cb.dataset.weekday, 10)
      const row = this.getRowForWeekday(wday)
      const rowOpens = row?.querySelector('input[type="time"][name*="opens_at"]')?.value
      cb.checked = !!rowOpens
    })
  }

  syncToRows() {
    this.syncOverrides()
  }

  getRowForWeekday(wday) {
    return this.windowRowTargets.find(r => parseInt(r.dataset.weekday, 10) === wday)
  }

  updatePreview() {
    if (!this.hasPreviewTarget) return

    const windows = []
    this.windowRowTargets.forEach(row => {
      const wday = parseInt(row.dataset.weekday, 10)
      const opensInput = row.querySelector('input[type="time"][name*="opens_at"]')
      const closesInput = row.querySelector('input[type="time"][name*="closes_at"]')
      const opens = opensInput?.value
      const closes = closesInput?.value
      if (opens && closes) windows.push({ weekday: wday, opens, closes })
    })

    const formatted = this.formatBusinessHours(windows)
    this.previewTarget.textContent = formatted || "—"
  }

  formatBusinessHours(windows) {
    if (!windows.length) return null

    const abbr = this.weekdayAbbrValue
    const everyDay = this.everyDayValue

    const groups = this.groupByTime(windows)
    return groups.map(({ days, opens, closes }) => {
      const dayStr = this.formatWeekdayRange(days.sort((a, b) => a - b), abbr, everyDay)
      return `${dayStr} ${opens}–${closes}`
    }).join(", ")
  }

  groupByTime(windows) {
    const map = new Map()
    windows.forEach(({ weekday, opens, closes }) => {
      const key = `${opens}|${closes}`
      if (!map.has(key)) map.set(key, { opens, closes, days: [] })
      map.get(key).days.push(weekday)
    })
    return Array.from(map.values())
  }

  formatWeekdayRange(days, abbr, everyDay) {
    const monFri = [ 1, 2, 3, 4, 5 ]
    const monSat = [ 1, 2, 3, 4, 5, 6 ]
    const all = [ 0, 1, 2, 3, 4, 5, 6 ]
    if (this.arraysEqual(days, monFri)) return `${abbr[1]}–${abbr[5]}`
    if (this.arraysEqual(days, monSat)) return `${abbr[1]}–${abbr[6]}`
    if (this.arraysEqual(days, all)) return everyDay
    return days.map(d => abbr[d]).join(", ")
  }

  arraysEqual(a, b) {
    if (a.length !== b.length) return false
    return a.every((v, i) => v === b[i])
  }
}
