# frozen_string_literal: true

require "test_helper"

# Stub job — Task 81 creates the real implementation
module Whatsapp
  class ProcessWebhookJob < ApplicationJob
    def perform(payload:); end
  end
end unless defined?(Whatsapp::ProcessWebhookJob)

module Whatsapp
  class WebhooksControllerTest < ActionDispatch::IntegrationTest
    TEST_VERIFY_TOKEN = "test_verify_token_xyz"
    TEST_APP_SECRET   = "test_app_secret_abc"

    def with_whatsapp_credentials(verify_token: TEST_VERIFY_TOKEN, app_secret: TEST_APP_SECRET, &block)
      fake_creds = Object.new
      fake_creds.define_singleton_method(:dig) do |*keys|
        last = keys.last
        case last
        when :verify_token then verify_token
        when :app_secret   then app_secret
        end
      end
      Rails.application.stub(:credentials, fake_creds, &block)
    end

    def valid_signature(body, secret = TEST_APP_SECRET)
      "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    end

    # ── GET verify ────────────────────────────────────────────────────────────

    test "GET with correct mode, verify_token, and challenge returns 200 with challenge body" do
      with_whatsapp_credentials do
        get whatsapp_webhooks_url,
            params: {
              "hub.mode"         => "subscribe",
              "hub.verify_token" => TEST_VERIFY_TOKEN,
              "hub.challenge"    => "abc123"
            }

        assert_response :ok
        assert_equal "abc123", response.body
      end
    end

    test "GET with wrong verify_token returns 403" do
      with_whatsapp_credentials do
        get whatsapp_webhooks_url,
            params: {
              "hub.mode"         => "subscribe",
              "hub.verify_token" => "wrong_token",
              "hub.challenge"    => "abc123"
            }

        assert_response :forbidden
      end
    end

    test "GET with missing hub.mode returns 403" do
      with_whatsapp_credentials do
        get whatsapp_webhooks_url,
            params: {
              "hub.verify_token" => TEST_VERIFY_TOKEN,
              "hub.challenge"    => "abc123"
            }

        assert_response :forbidden
      end
    end

    test "GET with wrong hub.mode returns 403" do
      with_whatsapp_credentials do
        get whatsapp_webhooks_url,
            params: {
              "hub.mode"         => "unsubscribe",
              "hub.verify_token" => TEST_VERIFY_TOKEN,
              "hub.challenge"    => "abc123"
            }

        assert_response :forbidden
      end
    end

    # ── POST receive ─────────────────────────────────────────────────────────

    test "POST with valid X-Hub-Signature-256 returns 200" do
      with_whatsapp_credentials do
        body = { entry: [] }.to_json
        post whatsapp_webhooks_url,
             params:  body,
             headers: {
               "Content-Type"        => "application/json",
               "X-Hub-Signature-256" => valid_signature(body)
             }

        assert_response :ok
      end
    end

    test "POST with invalid signature returns 401" do
      with_whatsapp_credentials do
        body = { entry: [] }.to_json
        post whatsapp_webhooks_url,
             params:  body,
             headers: {
               "Content-Type"        => "application/json",
               "X-Hub-Signature-256" => "sha256=invalidsignature"
             }

        assert_response :unauthorized
      end
    end

    test "POST with missing signature header returns 401" do
      with_whatsapp_credentials do
        body = { entry: [] }.to_json
        post whatsapp_webhooks_url,
             params:  body,
             headers: { "Content-Type" => "application/json" }

        assert_response :unauthorized
      end
    end

    test "valid POST enqueues Whatsapp::ProcessWebhookJob" do
      with_whatsapp_credentials do
        body = { entry: [] }.to_json
        assert_enqueued_with(job: Whatsapp::ProcessWebhookJob) do
          post whatsapp_webhooks_url,
               params:  body,
               headers: {
                 "Content-Type"        => "application/json",
                 "X-Hub-Signature-256" => valid_signature(body)
               }
        end
      end
    end

    test "POST does not require CSRF token" do
      with_whatsapp_credentials do
        body = { entry: [] }.to_json
        # ActionDispatch::IntegrationTest does not enforce CSRF by default,
        # but we verify no authenticity token is needed by omitting it explicitly.
        post whatsapp_webhooks_url,
             params:  body,
             headers: {
               "Content-Type"        => "application/json",
               "X-Hub-Signature-256" => valid_signature(body)
             }

        assert_response :ok
      end
    end

    test "invalid signature does not enqueue Whatsapp::ProcessWebhookJob" do
      with_whatsapp_credentials do
        assert_no_enqueued_jobs only: Whatsapp::ProcessWebhookJob do
          post whatsapp_webhooks_url,
               params:  { entry: [] }.to_json,
               headers: {
                 "Content-Type"        => "application/json",
                 "X-Hub-Signature-256" => "sha256=bad"
               }
        end
      end
    end
  end
end
