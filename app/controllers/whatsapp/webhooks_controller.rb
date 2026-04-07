# frozen_string_literal: true

module Whatsapp
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false
    skip_before_action :set_locale, raise: false
    skip_before_action :allow_browser, raise: false

    # GET /whatsapp/webhooks — Meta verification challenge
    def verify
      mode      = params["hub.mode"]
      token     = params["hub.verify_token"]
      challenge = params["hub.challenge"]

      if mode == "subscribe" && token.present? &&
         ActiveSupport::SecurityUtils.secure_compare(
           token.to_s,
           Rails.application.credentials.dig(:meta, :verify_token).to_s
         )
        render plain: challenge, status: :ok
      else
        head :forbidden
      end
    end

    # POST /whatsapp/webhooks — Incoming events
    def receive
      unless valid_signature?(request)
        head :unauthorized
        return
      end

      Whatsapp::ProcessWebhookJob.perform_later(payload: request.raw_post)
      head :ok
    end

    private

    def valid_signature?(request)
      signature = request.headers["X-Hub-Signature-256"]
      return false if signature.blank?

      app_secret = Rails.application.credentials.dig(:meta, :app_secret).to_s
      expected   = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", app_secret, request.raw_post)

      ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end
  end
end
