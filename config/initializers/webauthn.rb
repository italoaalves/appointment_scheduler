# frozen_string_literal: true

require Rails.root.join("lib/security/webauthn_config").to_s

Security::WebauthnConfig.configure!
