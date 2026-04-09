function base64urlToArrayBuffer(value) {
  const padding = "=".repeat((4 - (value.length % 4)) % 4)
  const base64 = `${value}${padding}`.replace(/-/g, "+").replace(/_/g, "/")
  const binary = window.atob(base64)
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0))
  return bytes.buffer
}

function arrayBufferToBase64url(value) {
  if (!value) return null

  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value)
  let binary = ""
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte)
  })

  return window.btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

export function parseCreationOptionsFromJSON(options) {
  if (window.PublicKeyCredential?.parseCreationOptionsFromJSON) {
    return window.PublicKeyCredential.parseCreationOptionsFromJSON(options)
  }

  const parsed = JSON.parse(JSON.stringify(options))
  parsed.challenge = base64urlToArrayBuffer(parsed.challenge)
  parsed.user.id = base64urlToArrayBuffer(parsed.user.id)
  parsed.excludeCredentials = (parsed.excludeCredentials || []).map((credential) => ({
    ...credential,
    id: base64urlToArrayBuffer(credential.id)
  }))

  return parsed
}

export function parseRequestOptionsFromJSON(options) {
  if (window.PublicKeyCredential?.parseRequestOptionsFromJSON) {
    return window.PublicKeyCredential.parseRequestOptionsFromJSON(options)
  }

  const parsed = JSON.parse(JSON.stringify(options))
  parsed.challenge = base64urlToArrayBuffer(parsed.challenge)
  parsed.allowCredentials = (parsed.allowCredentials || []).map((credential) => ({
    ...credential,
    id: base64urlToArrayBuffer(credential.id)
  }))

  return parsed
}

export function publicKeyCredentialToJSON(credential) {
  const response = credential.response

  const payload = {
    id: credential.id,
    rawId: arrayBufferToBase64url(credential.rawId),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment || null,
    clientExtensionResults: credential.getClientExtensionResults()
  }

  if (typeof AuthenticatorAttestationResponse !== "undefined" && response instanceof AuthenticatorAttestationResponse) {
    payload.response = {
      clientDataJSON: arrayBufferToBase64url(response.clientDataJSON),
      attestationObject: arrayBufferToBase64url(response.attestationObject),
      transports: typeof response.getTransports === "function" ? response.getTransports() : []
    }
  } else {
    payload.response = {
      clientDataJSON: arrayBufferToBase64url(response.clientDataJSON),
      authenticatorData: arrayBufferToBase64url(response.authenticatorData),
      signature: arrayBufferToBase64url(response.signature),
      userHandle: response.userHandle ? arrayBufferToBase64url(response.userHandle) : null
    }
  }

  return payload
}
