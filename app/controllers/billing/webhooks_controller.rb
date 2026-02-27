# frozen_string_literal: true

module Billing
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    before_action :verify_webhook_token

    def create
      Billing::ProcessWebhookJob.perform_later(payload: webhook_params.to_json)
      head :ok
    end

    private

    def verify_webhook_token
      token    = request.headers["asaas-access-token"].presence || params[:accessToken].presence
      expected = Rails.application.credentials.dig(:asaas, :webhook_token).presence ||
                 ENV["ASAAS_WEBHOOK_TOKEN"]

      return head :unauthorized if token.blank?
      return head :unauthorized if expected.blank?
      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(token, expected)
    end

    def webhook_params
      params.permit!.to_h
    end
  end
end
