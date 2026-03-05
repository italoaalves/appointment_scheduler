# frozen_string_literal: true

module Billing
  class ProcessWebhookJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(payload:)
      Billing::WebhookProcessor.call(payload)
    end
  end
end
