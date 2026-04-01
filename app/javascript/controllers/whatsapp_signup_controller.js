import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { appId: String }
  static targets = ["phoneNumberId", "displayNumber", "wabaId", "verifiedName", "form"]

  connect() {
    this.messageListener = this.handleSessionInfo.bind(this)
    window.addEventListener("message", this.messageListener)
    this.loadFacebookSDK()
  }

  disconnect() {
    window.removeEventListener("message", this.messageListener)
  }

  launch() {
    FB.login((response) => {
      // Session info is delivered via the message event listener;
      // FB.login callback alone does not carry phone number details.
    }, {
      config_id: this.appIdValue,
      response_type: "code",
      override_default_response_type: true,
      extras: {
        setup: {},
        featureType: "",
        sessionInfoVersion: "3"
      }
    })
  }

  handleSessionInfo(event) {
    if (event.origin !== "https://www.facebook.com") return

    let data
    try {
      data = typeof event.data === "string" ? JSON.parse(event.data) : event.data
    } catch {
      return
    }

    const { phone_number_id, display_phone_number, waba_id, verified_name } = data

    if (!phone_number_id || !waba_id) return

    this.phoneNumberIdTarget.value = phone_number_id
    this.displayNumberTarget.value = display_phone_number || ""
    this.wabaIdTarget.value = waba_id
    this.verifiedNameTarget.value = verified_name || ""

    this.formTarget.requestSubmit()
  }

  loadFacebookSDK() {
    if (document.getElementById("facebook-jssdk")) return

    const script = document.createElement("script")
    script.id = "facebook-jssdk"
    script.src = "https://connect.facebook.net/en_US/sdk.js"
    script.onload = () => {
      FB.init({
        appId: this.appIdValue,
        autoLogAppEvents: true,
        xfbml: true,
        version: "v22.0"
      })
    }
    document.head.appendChild(script)
  }
}
