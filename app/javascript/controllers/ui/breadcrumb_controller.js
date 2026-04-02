import { Controller } from "@hotwired/stimulus"

// Handles the floating breadcrumb pill behavior:
//   Desktop — hover expands ancestors to the left
//   Mobile  — "···" button opens a Hydro-Glass bottom sheet
export default class extends Controller {
  static targets = ["ancestors", "sheet", "overlay"]

  // Desktop: reveal full path on hover
  expand() {
    if (!this.hasAncestorsTarget) return
    this.ancestorsTarget.classList.remove("max-w-0", "opacity-0")
    this.ancestorsTarget.classList.add("max-w-xs", "opacity-100")
  }

  // Desktop: collapse back to parent + current
  collapse() {
    if (!this.hasAncestorsTarget) return
    this.ancestorsTarget.classList.add("max-w-0", "opacity-0")
    this.ancestorsTarget.classList.remove("max-w-xs", "opacity-100")
  }

  // Mobile: slide up the bottom sheet
  openSheet() {
    if (!this.hasSheetTarget) return
    this.overlayTarget.classList.remove("hidden")
    this.sheetTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.sheetTarget.classList.remove("translate-y-full")
      this.sheetTarget.classList.add("translate-y-0")
    })
  }

  // Mobile: slide down and hide the bottom sheet
  closeSheet() {
    if (!this.hasSheetTarget) return
    this.sheetTarget.classList.add("translate-y-full")
    this.sheetTarget.classList.remove("translate-y-0")
    setTimeout(() => {
      this.sheetTarget.classList.add("hidden")
      this.overlayTarget.classList.add("hidden")
    }, 200)
  }
}
