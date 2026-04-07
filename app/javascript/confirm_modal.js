// confirm_modal.js
//
// Replaces the browser's native confirm() dialog with a branded danger
// confirmation modal for every element that uses data-turbo-confirm.
//
// Uses Turbo.setConfirmMethod — the official Turbo 8 customisation point.
// Returns a Promise that resolves to true (confirm) or false (cancel).

import { Turbo } from "@hotwired/turbo-rails"

Turbo.setConfirmMethod((message, _element, _submitter) => {
  return new Promise((resolve) => {
    const body  = document.body
    const title        = body.dataset.confirmTitle || "Tem certeza?"
    const confirmLabel = body.dataset.confirmLabel || "Confirmar"
    const cancelLabel  = body.dataset.cancelLabel  || "Cancelar"

    const container = document.getElementById("modal_container")
    if (!container) { resolve(false); return }

    const overlay = document.createElement("div")
    overlay.className = "fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4"
    overlay.setAttribute("role", "dialog")
    overlay.setAttribute("aria-modal", "true")
    overlay.setAttribute("aria-labelledby", "confirm-modal-title")
    overlay.style.opacity = "0"
    overlay.style.transition = "opacity 200ms cubic-bezier(0.4, 0, 0.2, 1)"

    overlay.innerHTML = `
      <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" aria-hidden="true" data-role="backdrop"></div>
      <div class="relative z-10 w-full max-w-sm glass-frosty rounded-card p-6 text-center"
           data-role="panel"
           style="translate: 0 20px; transition: translate 250ms cubic-bezier(0.4, 0, 0.2, 1); padding-bottom: max(1.5rem, env(safe-area-inset-bottom));">
        <div class="mx-auto mb-4 flex items-center justify-center w-12 h-12 rounded-full bg-red-100">
          <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
          </svg>
        </div>
        <p id="confirm-modal-title"
           class="font-display font-bold text-deep text-base mb-2"
           data-role="title"></p>
        <p class="text-slate-600 text-sm leading-relaxed" data-role="message"></p>
        <div class="mt-5 flex flex-col gap-2">
          <button type="button" class="w-full btn-danger btn-sm" data-role="confirm"></button>
          <button type="button" class="w-full btn-muted btn-sm" data-role="cancel"></button>
        </div>
      </div>
    `

    // Set text safely via textContent
    overlay.querySelector("[data-role='title']").textContent   = title
    overlay.querySelector("[data-role='message']").textContent = message
    overlay.querySelector("[data-role='cancel']").textContent  = cancelLabel
    overlay.querySelector("[data-role='confirm']").textContent = confirmLabel

    container.appendChild(overlay)

    // Animate in
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        overlay.style.opacity = "1"
        const panel = overlay.querySelector("[data-role='panel']")
        if (panel) panel.style.translate = "0 0"
      })
    })

    const previousFocus = document.activeElement
    setTimeout(() => overlay.querySelector("[data-role='confirm']")?.focus(), 260)

    const onKeydown = (e) => { if (e.key === "Escape") close(false) }
    document.addEventListener("keydown", onKeydown)

    function close(confirmed) {
      document.removeEventListener("keydown", onKeydown)
      overlay.style.transition = "opacity 150ms cubic-bezier(0.4, 0, 0.2, 1)"
      overlay.style.opacity = "0"
      overlay.addEventListener("transitionend", () => {
        overlay.remove()
        previousFocus?.focus()
        resolve(confirmed)
      }, { once: true })
    }

    overlay.querySelector("[data-role='backdrop']")?.addEventListener("click", () => close(false))
    overlay.querySelector("[data-role='cancel']")?.addEventListener("click",   () => close(false))
    overlay.querySelector("[data-role='confirm']")?.addEventListener("click",  () => close(true))
  })
})
