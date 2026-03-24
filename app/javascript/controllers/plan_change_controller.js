import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "grid", "confirmation", "planIdInput", "paymentMethodInput",
    "currentName", "currentPrice",
    "newName", "newPrice",
    "upgradeNotice", "downgradeNotice", "manualPaymentWarning",
    "periodEnd"
  ]

  static values = {
    plans: Object,
    currentPrice: Number,
    paymentMethod: String
  }

  connect() {
    this.selectedPlanId = null
  }

  select(event) {
    const planId = event.params.id
    const plan = this.plansValue[planId]
    if (!plan) return

    this.selectedPlanId = planId

    this.newNameTarget.textContent = plan.name
    this.newPriceTarget.textContent = this.formatPrice(plan.price)
    this.planIdInputTarget.value = planId

    const isUpgrade = plan.price > this.currentPriceValue
    const isDowngrade = plan.price < this.currentPriceValue
    this.upgradeNoticeTarget.hidden = !isUpgrade
    this.downgradeNoticeTarget.hidden = !isDowngrade

    const needsManualPayment = ["pix", "boleto"].includes(this.paymentMethodValue)
    this.manualPaymentWarningTarget.hidden = !(isUpgrade && needsManualPayment)

    this.gridTarget.hidden = true
    this.confirmationTarget.hidden = false
  }

  back() {
    this.gridTarget.hidden = false
    this.confirmationTarget.hidden = true
  }

  confirm() {
    this.formTarget.requestSubmit()
  }

  updatePaymentMethod(event) {
    this.paymentMethodInputTarget.value = event.target.value
  }

  formatPrice(cents) {
    return "R$" + (cents / 100).toFixed(2).replace(".", ",") + "/mês"
  }
}
