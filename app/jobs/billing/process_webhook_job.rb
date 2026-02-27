# frozen_string_literal: true

module Billing
  class ProcessWebhookJob < ApplicationJob
    queue_as :default

    def perform(payload:)
      Billing::WebhookProcessor.call(payload)
    end
  end
end
