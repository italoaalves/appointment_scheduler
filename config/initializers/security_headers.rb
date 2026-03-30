# frozen_string_literal: true

# Additional security headers not covered by Rails defaults or CSP.
# These are set via Rack middleware to apply to all responses.

Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=()",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "SAMEORIGIN"
)
