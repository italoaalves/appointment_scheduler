# frozen_string_literal: true

require "test_helper"

module Whatsapp
  class ClientTest < ActiveSupport::TestCase
    # ── Helpers ───────────────────────────────────────────────────────────────

    # Returns a client whose HTTP layer is replaced by a simple lambda.
    # The lambda receives the Net::HTTP::Request and returns a fake response.
    # `captured` lets tests inspect the last outbound request.
    def stub_client(status_code:, response_body:)
      captured = { request: nil }

      fake_response = Object.new
      fake_response.define_singleton_method(:code) { status_code.to_s }
      fake_response.define_singleton_method(:body) do
        response_body.is_a?(String) ? response_body : response_body.to_json
      end

      adapter = lambda do |req|
        captured[:request] = req
        fake_response
      end

      client = Whatsapp::Client.new(
        phone_number_id: "12345",
        access_token:    "test_token",
        http_adapter:    adapter
      )
      [ client, captured ]
    end

    # ── send_template ─────────────────────────────────────────────────────────

    test "send_template builds correct JSON payload" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_template(
        to:            "5511999990001",
        template_name: "appointment_reminder",
        language:      "pt_BR",
        components:    []
      )

      req  = captured[:request]
      body = JSON.parse(req.body)

      assert_equal "whatsapp",      body["messaging_product"]
      assert_equal "individual",    body["recipient_type"]
      assert_equal "5511999990001", body["to"]
      assert_equal "template",      body["type"]

      tmpl = body["template"]
      assert_equal "appointment_reminder", tmpl["name"]
      assert_equal "pt_BR",               tmpl["language"]["code"]
      assert_equal [],                    tmpl["components"]
    end

    test "send_template normalizes phone by stripping non-digits" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_template(to: "+55 11 99999-0001", template_name: "reminder")

      body = JSON.parse(captured[:request].body)
      assert_equal "5511999990001", body["to"]
    end

    test "send_template uses default language pt_BR when not specified" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_template(to: "5511999990001", template_name: "welcome")

      body = JSON.parse(captured[:request].body)
      assert_equal "pt_BR", body["template"]["language"]["code"]
    end

    test "send_template includes components in template payload" do
      components = [ { "type" => "body", "parameters" => [ { "type" => "text", "text" => "João" } ] } ]

      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_template(
        to:            "5511999990001",
        template_name: "appointment_reminder",
        components:    components
      )

      body = JSON.parse(captured[:request].body)
      assert_equal components, body["template"]["components"]
    end

    # ── send_text ─────────────────────────────────────────────────────────────

    test "send_text builds correct JSON payload" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_text(to: "5511999990001", body: "Hello, world!")

      req  = captured[:request]
      body = JSON.parse(req.body)

      assert_equal "whatsapp",      body["messaging_product"]
      assert_equal "individual",    body["recipient_type"]
      assert_equal "5511999990001", body["to"]
      assert_equal "text",          body["type"]
      assert_equal "Hello, world!", body["text"]["body"]
    end

    test "send_text normalizes phone by stripping non-digits" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_text(to: "+55 (11) 9999-0001", body: "Hi")

      body = JSON.parse(captured[:request].body)
      assert_equal "551199990001", body["to"]
    end

    # ── mark_as_read ──────────────────────────────────────────────────────────

    test "mark_as_read sends status=read payload with message_id" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "success" => true }
      )

      client.mark_as_read(message_id: "wamid_abc123")

      body = JSON.parse(captured[:request].body)

      assert_equal "whatsapp",     body["messaging_product"]
      assert_equal "read",         body["status"]
      assert_equal "wamid_abc123", body["message_id"]
    end

    # ── Error handling ────────────────────────────────────────────────────────

    test "raises ApiError on non-2xx response" do
      client, = stub_client(
        status_code:   400,
        response_body: { "error" => { "message" => "Invalid parameter", "code" => 100 } }
      )

      error = assert_raises(Whatsapp::Client::ApiError) do
        client.send_text(to: "5511999990001", body: "Hi")
      end

      assert_equal 400, error.status
      assert_equal "Invalid parameter", error.message
      assert_equal({ "message" => "Invalid parameter", "code" => 100 }, error.error_data)
    end

    test "ApiError message comes from parsed error.message field" do
      client, = stub_client(
        status_code:   401,
        response_body: { "error" => { "message" => "The access token could not be decrypted", "code" => 190 } }
      )

      error = assert_raises(Whatsapp::Client::ApiError) do
        client.send_text(to: "5511999990001", body: "Hi")
      end

      assert_equal "The access token could not be decrypted", error.message
      assert_equal 401, error.status
    end

    test "ApiError falls back to 'Unknown API error' when error.message absent" do
      client, = stub_client(
        status_code:   500,
        response_body: "{}"
      )

      error = assert_raises(Whatsapp::Client::ApiError) do
        client.send_text(to: "5511999990001", body: "Hi")
      end

      assert_equal "Unknown API error", error.message
      assert_equal 500, error.status
    end

    # ── Constructor ───────────────────────────────────────────────────────────

    test "constructor accepts custom phone_number_id and access_token" do
      client = Whatsapp::Client.new(phone_number_id: "custom_id", access_token: "custom_token")

      assert_equal "custom_id",    client.instance_variable_get(:@phone_number_id)
      assert_equal "custom_token", client.instance_variable_get(:@access_token)
    end

    test "constructor defaults phone_number_id and access_token from credentials" do
      Rails.application.credentials.stub(:dig, ->(key, *rest) {
        case [ key, *rest ]
        when [ :whatsapp, :phone_number_id ] then "cred_phone_id"
        when [ :whatsapp, :access_token ]    then "cred_access_token"
        end
      }) do
        client = Whatsapp::Client.new

        assert_equal "cred_phone_id",     client.instance_variable_get(:@phone_number_id)
        assert_equal "cred_access_token", client.instance_variable_get(:@access_token)
      end
    end

    # ── Request headers ───────────────────────────────────────────────────────

    test "sets Authorization Bearer header on requests" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_text(to: "5511999990001", body: "Hi")

      assert_equal "Bearer test_token", captured[:request]["Authorization"]
    end

    test "sets Content-Type application/json header on requests" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_text(to: "5511999990001", body: "Hi")

      assert_equal "application/json", captured[:request]["Content-Type"]
    end

    # ── URL construction ──────────────────────────────────────────────────────

    test "posts to correct messages URL including phone_number_id" do
      client, captured = stub_client(
        status_code:   200,
        response_body: { "messages" => [ { "id" => "wamid_001" } ] }
      )

      client.send_text(to: "5511999990001", body: "Hi")

      assert_includes captured[:request].path, "/12345/messages"
    end
  end
end
