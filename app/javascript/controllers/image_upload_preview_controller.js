import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "previewImage", "placeholder", "status"]
  static values = { selectedMessage: String }

  connect() {
    this.objectUrl = null
    this.originalPreviewSrc = this.hasPreviewImageTarget ? this.previewImageTarget.getAttribute("src") : null
    this.originalPreviewHidden = this.hasPreviewImageTarget ? this.previewImageTarget.classList.contains("hidden") : true
    this.originalPlaceholderHidden = this.hasPlaceholderTarget ? this.placeholderTarget.classList.contains("hidden") : false
    this.originalStatus = this.hasStatusTarget ? this.statusTarget.textContent : ""
  }

  update() {
    const file = this.inputTarget.files && this.inputTarget.files[0]

    if (!file || !file.type.startsWith("image/")) {
      this.restore()
      return
    }

    this.revokeObjectUrl()
    this.objectUrl = URL.createObjectURL(file)

    if (this.hasPreviewImageTarget) {
      this.previewImageTarget.src = this.objectUrl
      this.previewImageTarget.classList.remove("hidden")
    }

    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden")
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.selectedMessageValue.replace("%{filename}", file.name)
    }
  }

  disconnect() {
    this.revokeObjectUrl()
  }

  restore() {
    this.revokeObjectUrl()

    if (this.hasPreviewImageTarget) {
      if (this.originalPreviewSrc) {
        this.previewImageTarget.src = this.originalPreviewSrc
      } else {
        this.previewImageTarget.removeAttribute("src")
      }

      this.previewImageTarget.classList.toggle("hidden", this.originalPreviewHidden)
    }

    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.toggle("hidden", this.originalPlaceholderHidden)
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.originalStatus
    }
  }

  revokeObjectUrl() {
    if (!this.objectUrl) return

    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }
}
