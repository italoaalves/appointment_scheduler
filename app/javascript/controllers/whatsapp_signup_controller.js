import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { appId: String }
  static targets = ["phoneNumberId", "displayNumber", "wabaId", "verifiedName", "form"]

  connect() {
    this.loadFacebookSDK()
  }

  launch() {
    FB.login((response) => {
      if (response.authResponse) {
        this.handleSuccess(response.authResponse)
      }
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

  handleSuccess(authResponse) {
    // Meta's Embedded Signup returns phone number details via message event
    // The form fields are populated by the sessionInfoListener and then submitted
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
