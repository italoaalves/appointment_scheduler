# frozen_string_literal: true

require "test_helper"

module Billing
  class WebhooksControllerTest < ActionDispatch::IntegrationTest
    VALID_PAYLOAD  = { event: "PAYMENT_CONFIRMED", payment: { id: "pay_001" } }.freeze
    TEST_TOKEN     = "test_webhook_token_abc123"

    setup    { ENV["ASAAS_WEBHOOK_TOKEN"] = TEST_TOKEN }
    teardown { ENV.delete("ASAAS_WEBHOOK_TOKEN") }

    def valid_token
      TEST_TOKEN
    end

    # ── Token verification ─────────────────────────────────────────────────────

    test "POST with valid asaas-access-token header returns 200" do
      post billing_webhooks_url,
           params:  VALID_PAYLOAD,
           headers: { "asaas-access-token" => valid_token }

      assert_response :ok
    end

    test "POST with valid token in accessToken param returns 200" do
      post billing_webhooks_url,
           params: VALID_PAYLOAD.merge(accessToken: valid_token)

      assert_response :ok
    end

    test "POST with missing token returns 401" do
      post billing_webhooks_url, params: VALID_PAYLOAD

      assert_response :unauthorized
    end

    test "POST with wrong token returns 401" do
      post billing_webhooks_url,
           params:  VALID_PAYLOAD,
           headers: { "asaas-access-token" => "wrong_token" }

      assert_response :unauthorized
    end

    # ── Job enqueueing ────────────────────────────────────────────────────────

    test "valid request enqueues ProcessWebhookJob" do
      assert_enqueued_with(job: Billing::ProcessWebhookJob) do
        post billing_webhooks_url,
             params:  VALID_PAYLOAD,
             headers: { "asaas-access-token" => valid_token }
      end
    end

    test "invalid token does not enqueue ProcessWebhookJob" do
      assert_no_enqueued_jobs only: Billing::ProcessWebhookJob do
        post billing_webhooks_url,
             params:  VALID_PAYLOAD,
             headers: { "asaas-access-token" => "wrong" }
      end
    end
  end
end
