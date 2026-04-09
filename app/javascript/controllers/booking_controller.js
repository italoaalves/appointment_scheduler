import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = [
    "flowStep",
    "stepPanel",
    "stepPreview",
    "stepState",
    "dateInput",
    "slotsContainer",
    "slotsList",
    "slotsStatus",
    "scheduledAt",
    "submitBtn",
    "slotTemplate",
    "errorTemplate",
    "summaryPlaceholder",
    "summaryContent",
    "summaryDate",
    "summaryTime",
    "slotsSync",
    "nameInput",
    "phoneInput",
    "emailInput",
    "whatsappPanel",
    "whatsappCheckbox"
  ]

  static values = {
    slotsUrl: String,
    businessWeekdays: Array,
    timezone: String,
    locale: String,
    stepLabels: Object
  }

  connect() {
    this.requestSequence = 0
    this.mobileHeroInteracted = false
    this.lastSlotsRefreshKey = this.hasSlotsSyncTarget ? this.slotsSyncTarget.dataset.refreshKey : null

    this.bindInputListeners()
    this.bindViewportListeners()
    this.initFlatpickr()
    this.syncWhatsappConsent()
    this.syncFormState({ initial: true })
    this.updateSummary()
    this.scheduleMobileHeroSync()
    this.loadSlots({ preserveSelection: this.hasSelectedSlot(), source: "initial" })
  }

  disconnect() {
    this.unbindInputListeners()
    this.unbindViewportListeners()
    this.cancelMobileHeroSync()
    if (this.flatpickrInstance) this.flatpickrInstance.destroy()
    this.abortInFlightRequest()
  }

  slotsSyncTargetConnected(element) {
    const refreshKey = element.dataset.refreshKey
    if (!refreshKey) return

    if (!this.lastSlotsRefreshKey) {
      this.lastSlotsRefreshKey = refreshKey
      return
    }

    if (this.lastSlotsRefreshKey === refreshKey) return

    this.lastSlotsRefreshKey = refreshKey
    this.loadSlots({ preserveSelection: this.hasSelectedSlot(), background: true, source: "live" })
  }

  initFlatpickr() {
    const input = this.dateInputTarget
    if (!input) return

    const min = input.min
    const max = input.max
    const businessWeekdays = this.hasBusinessWeekdaysValue ? this.businessWeekdaysValue : null
    const initialDate = input.value
    const pickerMin = min ? new Date(`${min}T12:00:00`) : null
    const pickerMax = max ? new Date(`${max}T12:00:00`) : null

    const options = {
      dateFormat: "Y-m-d",
      minDate: pickerMin,
      maxDate: pickerMax,
      defaultDate: initialDate || undefined,
      onChange: (_selectedDates, dateStr) => {
        input.value = dateStr
        this.queueDateRefresh()
      }
    }

    if (businessWeekdays && businessWeekdays.length > 0) {
      options.disable = [
        (date) => !businessWeekdays.includes(date.getDay())
      ]
    }

    this.flatpickrInstance = flatpickr(input, options)

    if (initialDate && businessWeekdays?.length > 0) {
      const date = new Date(`${initialDate}T12:00:00`)
      if (!businessWeekdays.includes(date.getDay())) {
        const nextDate = this.nextBusinessDate(date, businessWeekdays)
        if (nextDate) {
          this.flatpickrInstance.setDate(nextDate, false)
          input.value = nextDate.toISOString().slice(0, 10)
        }
      }
    }
  }

  nextBusinessDate(from, weekdays) {
    const date = new Date(from)

    for (let index = 0; index < 14; index += 1) {
      if (weekdays.includes(date.getDay())) return date
      date.setDate(date.getDate() + 1)
    }

    return null
  }

  loadSlots({ preserveSelection = false, background = false, source = "manual" } = {}) {
    const dateInput = this.dateInputTarget
    if (!dateInput || !dateInput.value) return

    const date = dateInput.value
    const selectedSlotValue = preserveSelection ? this.selectedSlotValue() : ""
    const slotsUrl = this.hasSlotsUrlValue ? this.slotsUrlValue : this.defaultSlotsUrl()

    this.abortInFlightRequest()
    this.renderLoadingState({ background })

    const abortController = new AbortController()
    const requestId = ++this.requestSequence
    this.abortController = abortController

    fetch(`${slotsUrl}?from=${encodeURIComponent(date)}&to=${encodeURIComponent(date)}`, {
      cache: "no-store",
      credentials: "same-origin",
      headers: {
        Accept: "application/json"
      },
      signal: abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error("fetch failed")
        return response.json()
      })
      .then((slots) => {
        if (requestId !== this.requestSequence) return

        this.abortController = null
        this.renderSlots(slots, { selectedSlotValue, source })
      })
      .catch((error) => {
        if (error.name === "AbortError" || requestId !== this.requestSequence) return

        this.abortController = null
        this.showError({ background })
      })
  }

  renderLoadingState({ background = false } = {}) {
    this.slotsStatusTarget.textContent = background
      ? this.slotsContainerTarget.dataset.refreshingText || this.slotsContainerTarget.dataset.loadingText || "Loading..."
      : this.slotsContainerTarget.dataset.loadingText || "Loading..."
    this.slotsListTarget.setAttribute("aria-busy", "true")

    if (background) return

    this.slotsListTarget.innerHTML = ""

    for (let index = 0; index < 6; index += 1) {
      const skeleton = document.createElement("div")
      skeleton.className = "booking-slot-skeleton"
      skeleton.setAttribute("aria-hidden", "true")
      this.slotsListTarget.appendChild(skeleton)
    }
  }

  renderSlots(slots, { selectedSlotValue = "", source = "manual" } = {}) {
    this.slotsListTarget.innerHTML = ""
    this.slotsListTarget.setAttribute("aria-busy", "false")

    const previousSelection = selectedSlotValue.trim()
    let restoredSelection = null

    if (slots.length === 0) {
      if (previousSelection && source !== "date") {
        this.clearSelectedSlot()
        this.slotsStatusTarget.textContent = this.selectedUnavailableText()
      } else {
        this.slotsStatusTarget.textContent = this.slotsContainerTarget.dataset.emptyText || "No available slots for this date."
      }

      const message = document.createElement("div")
      message.className = "booking-slot-feedback"
      message.textContent = this.slotsContainerTarget.dataset.emptyText || "No available slots for this date."
      this.slotsListTarget.appendChild(message)
      return
    }

    this.slotsStatusTarget.textContent = this.slotsContainerTarget.dataset.chooseText || "Choose a time:"

    slots.forEach((slot) => {
      const button = this.slotTemplateTarget.content.cloneNode(true).querySelector("button")
      const label = this.formatTime(slot.value, slot.label)
      const context = this.slotContextLabel(slot.value)

      button.dataset.slotValue = slot.value
      button.dataset.slotLabel = label
      button.setAttribute("aria-pressed", "false")
      button.querySelector("[data-slot-context]").textContent = context
      button.querySelector("[data-slot-label]").textContent = label
      button.addEventListener("click", () => this.selectSlot(button))

      if (slot.value === previousSelection) restoredSelection = button
      this.slotsListTarget.appendChild(button)
    })

    if (restoredSelection) {
      this.applySelectedSlot(restoredSelection)
      return
    }

    if (previousSelection && source !== "date") {
      this.clearSelectedSlot()
      this.slotsStatusTarget.textContent = this.selectedUnavailableText()
    }
  }

  showError({ background = false } = {}) {
    if (background) {
      this.slotsStatusTarget.textContent = this.slotsContainerTarget.dataset.errorText || "Could not load available times."
      this.slotsListTarget.setAttribute("aria-busy", "false")
      return
    }

    const error = this.errorTemplateTarget.content.cloneNode(true)
    const message = error.querySelector("p")
    const retryButton = error.querySelector("button")

    message.textContent = this.slotsContainerTarget.dataset.errorText || "Could not load available times."
    retryButton.textContent = this.slotsContainerTarget.dataset.retryText || "Try again"
    retryButton.addEventListener("click", () => this.loadSlots())

    this.slotsStatusTarget.textContent = ""
    this.slotsListTarget.innerHTML = ""
    this.slotsListTarget.setAttribute("aria-busy", "false")
    this.slotsListTarget.appendChild(error)
  }

  selectSlot(button) {
    this.markMobileHeroInteracted()
    this.applySelectedSlot(button)
  }

  applySelectedSlot(button) {
    this.slotsListTarget.querySelectorAll(".booking-slot-option").forEach((slotButton) => {
      slotButton.classList.remove("booking-slot-option-selected")
      slotButton.setAttribute("aria-pressed", "false")
    })

    button.classList.add("booking-slot-option-selected")
    button.setAttribute("aria-pressed", "true")
    this.scheduledAtTarget.value = button.dataset.slotValue
    this.updateSummary()
    this.syncFormState()
  }

  queueDateRefresh() {
    const dateValue = this.dateInputTarget.value
    if (!dateValue) return

    this.pendingDateValue = dateValue
    clearTimeout(this.dateRefreshTimer)

    this.dateRefreshTimer = setTimeout(() => {
      this.pendingDateValue = null
      this.clearSelectedSlot()
      this.loadSlots({ source: "date" })
    }, 0)
  }

  syncFormState({ initial = false } = {}) {
    const hasName = this.nameInputTarget.value.trim().length > 0
    const hasContact = this.phoneInputTarget.value.trim().length > 0 || this.emailInputTarget.value.trim().length > 0
    const hasSelectedSlot = this.scheduledAtTarget.value.trim().length > 0

    this.submitBtnTarget.disabled = !(hasName && hasContact && hasSelectedSlot)
    this.scheduleMobileHeroSync()
    this.updateStepFlow({ initial })
  }

  syncWhatsappConsent() {
    const hasPhone = this.phoneInputTarget.value.trim().length > 0

    this.whatsappPanelTarget.classList.toggle("booking-consent-panel-disabled", !hasPhone)

    if (hasPhone) {
      this.whatsappCheckboxTarget.removeAttribute("disabled")
      return
    }

    this.whatsappCheckboxTarget.setAttribute("disabled", "disabled")
    this.whatsappCheckboxTarget.checked = false
  }

  updateSummary() {
    if (!this.hasSummaryPlaceholderTarget || !this.hasSummaryContentTarget) return

    const selectedSlot = this.scheduledAtTarget.value

    if (!selectedSlot) {
      this.summaryPlaceholderTarget.classList.remove("booking-summary-placeholder-hidden")
      this.summaryPlaceholderTarget.classList.add("booking-summary-placeholder-visible")
      this.summaryContentTarget.classList.remove("booking-summary-content-visible")
      this.summaryContentTarget.classList.add("booking-summary-content-hidden")
      return
    }

    this.summaryDateTarget.textContent = this.formatDate(this.dateInputTarget.value)
    this.summaryTimeTarget.textContent = this.formatTime(selectedSlot)
    this.summaryPlaceholderTarget.classList.remove("booking-summary-placeholder-visible")
    this.summaryPlaceholderTarget.classList.add("booking-summary-placeholder-hidden")
    this.summaryContentTarget.classList.remove("booking-summary-content-hidden")
    this.summaryContentTarget.classList.add("booking-summary-content-visible")
  }

  clearSelectedSlot() {
    if (this.hasScheduledAtTarget) this.scheduledAtTarget.value = ""
    this.updateSummary()
    this.syncFormState()
  }

  detailsComplete() {
    return this.nameInputTarget.value.trim().length > 0 &&
      (this.phoneInputTarget.value.trim().length > 0 || this.emailInputTarget.value.trim().length > 0)
  }

  updateStepFlow({ initial = false } = {}) {
    const hasSlot = this.hasSelectedSlot()
    const detailsComplete = this.detailsComplete()

    this.applyStepState("schedule", hasSlot ? "complete" : "current", { initial })
    this.applyStepState("details", hasSlot ? (detailsComplete ? "complete" : "current") : "locked", { initial })
    this.applyStepState("review", hasSlot && detailsComplete ? "current" : "locked", { initial })
  }

  applyStepState(stepName, state, { initial = false } = {}) {
    const card = this.flowStepTargets.find((target) => target.dataset.stepName === stepName)
    if (!card) return

    const panel = this.stepPanelTargets.find((target) => target.dataset.stepName === stepName)
    const preview = this.stepPreviewTargets.find((target) => target.dataset.stepName === stepName)
    const badge = this.stepStateTargets.find((target) => target.dataset.stepName === stepName)
    const unlocked = stepName === "schedule" || state !== "locked"

    card.classList.remove("booking-step-card-current", "booking-step-card-complete", "booking-step-card-locked")
    card.classList.add(`booking-step-card-${state}`)

    if (panel) {
      panel.classList.toggle("booking-step-panel-open", unlocked)
      panel.classList.toggle("booking-step-panel-hidden", !unlocked)
    }

    if (preview) {
      preview.classList.toggle("booking-step-preview-visible", !unlocked)
      preview.classList.toggle("booking-step-preview-hidden", unlocked)
    }

    if (badge) {
      badge.textContent = this.stepStateLabel(state)
      badge.classList.remove("booking-step-state-current", "booking-step-state-complete", "booking-step-state-locked")
      badge.classList.add(`booking-step-state-${state}`)
    }

    if (unlocked && stepName !== "schedule") {
      if (card.dataset.unlockedOnce !== "true" && !initial) {
        card.dataset.unlockedOnce = "true"
        this.scrollStepIntoView(card)
      } else {
        card.dataset.unlockedOnce = "true"
      }
      return
    }

    if (!unlocked && stepName !== "schedule") {
      card.dataset.unlockedOnce = "false"
    }
  }

  stepStateLabel(state) {
    const labels = this.hasStepLabelsValue ? this.stepLabelsValue : {}

    return labels[state] || {
      current: "Current",
      complete: "Ready",
      locked: "Up next"
    }[state]
  }

  scrollStepIntoView(card) {
    if (!card) return

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        this.releaseScrollAnchor(card)
        const anchor = this.stepScrollAnchor(card)

        const top = Math.max(
          this.currentScrollTop() + anchor.getBoundingClientRect().top - this.nextAvailableTopSlot(card),
          0
        )

        window.scrollTo({ top, behavior: "auto" })
      })
    })
  }

  stepScrollAnchor(card) {
    return card.querySelector(".booking-step-heading") || card
  }

  nextAvailableTopSlot(card) {
    const stickyElements = this.activeStickyScrollCandidates(card)
    if (stickyElements.length === 0) return this.stickyScrollGap()

    let stackBottom = 0

    stickyElements.forEach((element) => {
      const top = Number.parseFloat(getComputedStyle(element).top) || 0
      stackBottom = Math.max(stackBottom, top + element.offsetHeight)
    })

    return stackBottom
  }

  stickyScrollGap() {
    const rootStyles = getComputedStyle(document.documentElement)
    return Number.parseFloat(rootStyles.getPropertyValue("--spacing-sticky-filter")) || 16
  }

  releaseScrollAnchor(card) {
    const activeElement = document.activeElement
    if (!activeElement || activeElement === document.body || card.contains(activeElement)) return
    if (this.textEntryElement(activeElement)) return
    if (typeof activeElement.blur === "function") activeElement.blur()
  }

  textEntryElement(element) {
    if (!element || !("tagName" in element)) return false
    if (element.tagName === "TEXTAREA") return true
    if (element.tagName !== "INPUT") return false

    return !["button", "checkbox", "radio", "submit"].includes(element.type)
  }

  activeStickyScrollCandidates(card) {
    const cardRect = card.getBoundingClientRect()
    return Array.from(document.querySelectorAll([
      "[data-sticky-stack-target='filter']",
      "[data-sticky-stack-target='section']",
      ".sticky-filter",
      ".sticky-section",
      ".booking-hero-sticky"
    ].join(", "))).filter((element) => {
      if (!element || element === card || !element.isConnected) return false

      const styles = getComputedStyle(element)
      if (!["sticky", "fixed"].includes(styles.position)) return false

      const rect = element.getBoundingClientRect()
      if (rect.width < 1 || rect.height < 1) return false
      if (rect.right <= cardRect.left || rect.left >= cardRect.right) return false

      const pinnedTop = Number.parseFloat(styles.top) || 0
      return rect.bottom > 0 && rect.top <= pinnedTop + 1
    })
  }

  formatDate(dateValue) {
    if (!dateValue) return ""

    const formatter = new Intl.DateTimeFormat(this.locale(), {
      weekday: "short",
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: this.timezone()
    })

    return formatter.format(new Date(`${dateValue}T12:00:00`))
  }

  formatTime(slotValue, fallbackLabel = "") {
    if (!slotValue) return fallbackLabel

    const formatter = new Intl.DateTimeFormat(this.locale(), {
      hour: "2-digit",
      minute: "2-digit",
      timeZone: this.timezone()
    })

    return formatter.format(new Date(slotValue))
  }

  slotContextLabel(slotValue) {
    const hour = this.slotHour(slotValue)
    if (hour === null) return ""

    if (hour < 5) return this.slotsContainerTarget.dataset.nightText || "Night"
    if (hour < 12) return this.slotsContainerTarget.dataset.morningText || "Morning"
    if (hour < 18) return this.slotsContainerTarget.dataset.afternoonText || "Afternoon"

    return this.slotsContainerTarget.dataset.eveningText || "Evening"
  }

  slotHour(slotValue) {
    if (!slotValue) return null

    const parts = new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      hour12: false,
      timeZone: this.timezone()
    }).formatToParts(new Date(slotValue))

    const hourPart = parts.find((part) => part.type === "hour")
    const hour = Number.parseInt(hourPart?.value || "", 10)

    return Number.isNaN(hour) ? null : hour
  }

  selectedSlotValue() {
    return this.hasScheduledAtTarget ? this.scheduledAtTarget.value.trim() : ""
  }

  hasSelectedSlot() {
    return this.selectedSlotValue().length > 0
  }

  selectedUnavailableText() {
    return this.slotsContainerTarget.dataset.selectedUnavailableText || "That time is no longer available. Please choose another."
  }

  locale() {
    return this.hasLocaleValue ? this.localeValue : document.documentElement.lang || "en"
  }

  timezone() {
    return this.hasTimezoneValue ? this.timezoneValue : Intl.DateTimeFormat().resolvedOptions().timeZone
  }

  bindViewportListeners() {
    this.scrollListener = () => this.scheduleMobileHeroSync()
    this.resizeListener = () => this.scheduleMobileHeroSync()

    window.addEventListener("scroll", this.scrollListener, { passive: true })
    document.addEventListener("scroll", this.scrollListener, { passive: true })
    window.addEventListener("resize", this.resizeListener)

    if (window.visualViewport) {
      window.visualViewport.addEventListener("scroll", this.scrollListener)
      window.visualViewport.addEventListener("resize", this.resizeListener)
    }
  }

  unbindViewportListeners() {
    if (this.scrollListener) window.removeEventListener("scroll", this.scrollListener)
    if (this.scrollListener) document.removeEventListener("scroll", this.scrollListener)
    if (this.resizeListener) window.removeEventListener("resize", this.resizeListener)

    if (window.visualViewport) {
      if (this.scrollListener) window.visualViewport.removeEventListener("scroll", this.scrollListener)
      if (this.resizeListener) window.visualViewport.removeEventListener("resize", this.resizeListener)
    }
  }

  scheduleMobileHeroSync() {
    this.cancelMobileHeroSync()
    this.mobileHeroSyncFrame = window.requestAnimationFrame(() => {
      this.mobileHeroSyncFrame = null
      this.syncMobileHeroState()
    })
  }

  cancelMobileHeroSync() {
    if (!this.mobileHeroSyncFrame) return

    window.cancelAnimationFrame(this.mobileHeroSyncFrame)
    this.mobileHeroSyncFrame = null
  }

  syncMobileHeroState() {
    const shouldCompact = this.shouldCompactMobileHero()
    this.element.classList.toggle("booking-page-mobile-hero-compact", shouldCompact)
  }

  shouldCompactMobileHero() {
    if (!window.matchMedia("(max-width: 1023px)").matches) return false

    return this.currentScrollTop() > 16 || this.mobileHeroInteracted || this.detailsStarted()
  }

  currentScrollTop() {
    return Math.max(
      window.scrollY || 0,
      window.pageYOffset || 0,
      document.documentElement?.scrollTop || 0,
      document.body?.scrollTop || 0,
      window.visualViewport?.pageTop || 0
    )
  }

  detailsStarted() {
    return [this.nameInputTarget, this.phoneInputTarget, this.emailInputTarget]
      .some((input) => input.value.trim().length > 0)
  }

  markMobileHeroInteracted() {
    if (this.mobileHeroInteracted) return

    this.mobileHeroInteracted = true
    this.scheduleMobileHeroSync()
  }

  bindInputListeners() {
    this.dateInputListener = () => {
      this.markMobileHeroInteracted()
      this.queueDateRefresh()
    }
    this.nameInputListener = () => {
      this.markMobileHeroInteracted()
      this.syncFormState()
    }
    this.phoneInputListener = () => {
      this.markMobileHeroInteracted()
      this.syncFormState()
      this.syncWhatsappConsent()
    }
    this.emailInputListener = () => {
      this.markMobileHeroInteracted()
      this.syncFormState()
    }
    this.whatsappInputListener = () => this.markMobileHeroInteracted()

    this.dateInputTarget.addEventListener("change", this.dateInputListener)
    this.nameInputTarget.addEventListener("input", this.nameInputListener)
    this.nameInputTarget.addEventListener("change", this.nameInputListener)
    this.phoneInputTarget.addEventListener("input", this.phoneInputListener)
    this.phoneInputTarget.addEventListener("change", this.phoneInputListener)
    this.emailInputTarget.addEventListener("input", this.emailInputListener)
    this.emailInputTarget.addEventListener("change", this.emailInputListener)
    if (this.hasWhatsappCheckboxTarget) {
      this.whatsappCheckboxTarget.addEventListener("input", this.whatsappInputListener)
      this.whatsappCheckboxTarget.addEventListener("change", this.whatsappInputListener)
    }
  }

  unbindInputListeners() {
    clearTimeout(this.dateRefreshTimer)
    if (this.dateInputListener) this.dateInputTarget.removeEventListener("change", this.dateInputListener)
    if (this.nameInputListener) {
      this.nameInputTarget.removeEventListener("input", this.nameInputListener)
      this.nameInputTarget.removeEventListener("change", this.nameInputListener)
    }
    if (this.phoneInputListener) {
      this.phoneInputTarget.removeEventListener("input", this.phoneInputListener)
      this.phoneInputTarget.removeEventListener("change", this.phoneInputListener)
    }
    if (this.emailInputListener) {
      this.emailInputTarget.removeEventListener("input", this.emailInputListener)
      this.emailInputTarget.removeEventListener("change", this.emailInputListener)
    }
    if (this.whatsappInputListener && this.hasWhatsappCheckboxTarget) {
      this.whatsappCheckboxTarget.removeEventListener("input", this.whatsappInputListener)
      this.whatsappCheckboxTarget.removeEventListener("change", this.whatsappInputListener)
    }
  }

  abortInFlightRequest() {
    if (!this.abortController) return

    this.abortController.abort()
    this.abortController = null
  }

  defaultSlotsUrl() {
    const path = window.location.pathname.replace(/\/thank-you$/, "")
    return path.endsWith("/slots") ? path : `${path}/slots`
  }
}
