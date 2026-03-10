# frozen_string_literal: true

require "test_helper"

module Billing
  class WebhooksControllerTest < ActionDispatch::IntegrationTest
    VALID_PAYLOAD  = { event: "PAYMENT_CONFIRMED", payment: { id: "pay_001" } }.freeze
    TEST_TOKEN     = "test_webhook_token_abc123"

    def valid_token
      TEST_TOKEN
    end

    # Wraps a block with stubbed credentials returning the given token.
    def with_webhook_credentials(token = TEST_TOKEN, &block)
      fake_creds = Object.new
      fake_creds.define_singleton_method(:dig) { |*_args| token }
      Rails.application.stub(:credentials, fake_creds, &block)
    end

    # ── Token verification ─────────────────────────────────────────────────────

    test "POST with valid asaas-access-token header returns 200" do
      with_webhook_credentials do
        post billing_webhooks_url,
             params:  VALID_PAYLOAD,
             headers: { "asaas-access-token" => valid_token }

        assert_response :ok
      end
    end

    test "POST with valid token in accessToken param returns 200" do
      with_webhook_credentials do
        post billing_webhooks_url,
             params: VALID_PAYLOAD.merge(accessToken: valid_token)

        assert_response :ok
      end
    end

    test "POST with missing token returns 401" do
      with_webhook_credentials do
        post billing_webhooks_url, params: VALID_PAYLOAD

        assert_response :unauthorized
      end
    end

    test "POST with wrong token returns 401" do
      with_webhook_credentials do
        post billing_webhooks_url,
             params:  VALID_PAYLOAD,
             headers: { "asaas-access-token" => "wrong_token" }

        assert_response :unauthorized
      end
    end

    test "POST returns 401 when webhook_token credential is not configured" do
      with_webhook_credentials(nil) do
        post billing_webhooks_url,
             params:  VALID_PAYLOAD,
             headers: { "asaas-access-token" => "any_token" }

        assert_response :unauthorized
      end
    end

    # ── Job enqueueing ────────────────────────────────────────────────────────

    test "valid request enqueues ProcessWebhookJob" do
      with_webhook_credentials do
        assert_enqueued_with(job: Billing::ProcessWebhookJob) do
          post billing_webhooks_url,
               params:  VALID_PAYLOAD,
               headers: { "asaas-access-token" => valid_token }
        end
      end
    end

    test "enqueued job receives the raw request body as payload" do
      with_webhook_credentials do
        post billing_webhooks_url,
             params:  VALID_PAYLOAD.to_json,
             headers: { "asaas-access-token" => valid_token, "Content-Type" => "application/json" }

        assert_response :ok

        job = enqueued_jobs.find { |j| j["job_class"] == "Billing::ProcessWebhookJob" }
        assert job, "Expected ProcessWebhookJob to be enqueued"

        serialized_payload = job["arguments"].first["payload"]
        parsed = JSON.parse(serialized_payload)
        assert_equal "PAYMENT_CONFIRMED", parsed["event"]
        assert_equal "pay_001", parsed.dig("payment", "id")
      end
    end

    test "invalid token does not enqueue ProcessWebhookJob" do
      with_webhook_credentials do
        assert_no_enqueued_jobs only: Billing::ProcessWebhookJob do
          post billing_webhooks_url,
               params:  VALID_PAYLOAD,
               headers: { "asaas-access-token" => "wrong" }
        end
      end
    end
  end
end
