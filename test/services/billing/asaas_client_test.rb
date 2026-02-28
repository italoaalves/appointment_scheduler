# frozen_string_literal: true

require "test_helper"

module Billing
  class AsaasClientTest < ActiveSupport::TestCase
    # ── Helpers ───────────────────────────────────────────────────────────────

    # Returns a client whose HTTP layer is replaced by a simple lambda.
    # The lambda receives the Net::HTTP::Request and returns a fake response.
    # `captured` lets tests inspect the last outbound request.
    def stub_client(status_code:, response_body:)
      captured = { request: nil }

      fake_response = Object.new
      fake_response.define_singleton_method(:code) { status_code.to_s }
      fake_response.define_singleton_method(:body) { response_body }

      adapter = lambda do |req|
        captured[:request] = req
        fake_response
      end

      client = Billing::AsaasClient.new(http_adapter: adapter)
      [ client, captured ]
    end

    # ── Initialization ────────────────────────────────────────────────────────

    test "defaults base_url to Asaas sandbox when credentials absent" do
      client = Billing::AsaasClient.new
      assert_includes client.instance_variable_get(:@base_url), "sandbox.asaas.com"
    end

    # ── create_customer ───────────────────────────────────────────────────────

    test "create_customer sends correct headers and body" do
      client, captured = stub_client(status_code: 200, response_body: '{"id":"cus_001","name":"Maria"}')

      result = client.create_customer(
        name:               "Maria",
        email:              "maria@example.com",
        cpf_cnpj:           "123.456.789-00",
        external_reference: "space_1"
      )

      assert_equal "cus_001", result["id"]
      assert_equal "Maria",   result["name"]

      req = captured[:request]
      assert_not_nil req
      assert_equal client.instance_variable_get(:@api_key), req["access-token"]
      assert_equal "application/json", req["Content-Type"]

      body = JSON.parse(req.body)
      assert_equal "Maria",             body["name"]
      assert_equal "maria@example.com", body["email"]
      assert_equal "123.456.789-00",    body["cpfCnpj"]
      assert_equal "space_1",           body["externalReference"]
    end

    # ── create_subscription ───────────────────────────────────────────────────

    test "create_subscription maps :pix to PIX" do
      client, captured = stub_client(status_code: 200, response_body: '{"id":"sub_001"}')

      client.create_subscription(
        customer_id: "cus_001", billing_type: :pix, value: 99.0,
        next_due_date: "2026-03-01", description: "Starter", external_reference: "space_1"
      )

      assert_equal "PIX", JSON.parse(captured[:request].body)["billingType"]
    end

    test "create_subscription maps :credit_card to CREDIT_CARD" do
      client, captured = stub_client(status_code: 200, response_body: '{"id":"sub_002"}')

      client.create_subscription(
        customer_id: "cus_001", billing_type: :credit_card, value: 99.0,
        next_due_date: "2026-03-01", description: "Pro", external_reference: "space_2"
      )

      assert_equal "CREDIT_CARD", JSON.parse(captured[:request].body)["billingType"]
    end

    test "create_subscription maps :boleto to BOLETO" do
      client, captured = stub_client(status_code: 200, response_body: '{"id":"sub_003"}')

      client.create_subscription(
        customer_id: "cus_001", billing_type: :boleto, value: 99.0,
        next_due_date: "2026-03-01", description: "Starter", external_reference: "space_3"
      )

      assert_equal "BOLETO", JSON.parse(captured[:request].body)["billingType"]
    end

    test "create_subscription raises ArgumentError for unknown billing_type" do
      client, = stub_client(status_code: 200, response_body: "{}")

      assert_raises(ArgumentError) do
        client.create_subscription(
          customer_id: "cus_001", billing_type: :wire_transfer, value: 99.0,
          next_due_date: "2026-03-01", description: "Plan", external_reference: "space_1"
        )
      end
    end

    test "create_subscription includes cycle and sets MONTHLY by default" do
      client, captured = stub_client(status_code: 200, response_body: '{"id":"sub_004"}')

      client.create_subscription(
        customer_id: "cus_001", billing_type: :pix, value: 99.0,
        next_due_date: "2026-03-01", description: "Pro", external_reference: "space_1"
      )

      assert_equal "MONTHLY", JSON.parse(captured[:request].body)["cycle"]
    end

    # ── Error handling ────────────────────────────────────────────────────────

    test "400 response raises ApiError with correct status_code and body" do
      client, = stub_client(status_code: 400, response_body: '{"errors":[{"description":"Invalid CPF"}]}')

      error = assert_raises(Billing::AsaasClient::ApiError) do
        client.create_customer(
          name: "Maria", email: "m@x.com", cpf_cnpj: "000", external_reference: "s1"
        )
      end

      assert_equal 400, error.status_code
      assert_includes error.body, "Invalid CPF"
      assert_includes error.message, "400"
    end

    test "401 response raises ApiError" do
      client, = stub_client(status_code: 401, response_body: '{"errors":[{"description":"Unauthorized"}]}')

      error = assert_raises(Billing::AsaasClient::ApiError) { client.find_customer("cus_bad") }
      assert_equal 401, error.status_code
    end

    test "404 response raises ApiError" do
      client, = stub_client(status_code: 404, response_body: '{"errors":[{"description":"Not found"}]}')

      assert_raises(Billing::AsaasClient::ApiError) { client.find_subscription("sub_missing") }
    end

    # ── find_customer ─────────────────────────────────────────────────────────

    test "find_customer returns parsed response hash" do
      client, = stub_client(status_code: 200, response_body: '{"id":"cus_001","name":"Maria"}')

      result = client.find_customer("cus_001")
      assert_equal "cus_001", result["id"]
    end

    # ── Payments ──────────────────────────────────────────────────────────────

    test "list_payments appends subscription query param to URI" do
      client, captured = stub_client(status_code: 200, response_body: '{"data":[]}')

      result = client.list_payments(subscription_id: "sub_001")
      assert_equal [], result["data"]
      assert_includes captured[:request].path, "subscription=sub_001"
    end

    # ── cancel_subscription ───────────────────────────────────────────────────

    test "cancel_subscription sends DELETE to /subscriptions/:id (no /cancel suffix)" do
      client, captured = stub_client(status_code: 200, response_body: '{"deleted":true}')

      result = client.cancel_subscription("sub_001")
      assert result["deleted"]
      assert_kind_of Net::HTTP::Delete, captured[:request]
      assert_includes captured[:request].path, "/subscriptions/sub_001"
      assert_not_includes captured[:request].path, "/cancel"
    end

    # ── create_payment ────────────────────────────────────────────────────────

    test "create_payment POSTs to /payments with correct body" do
      client, captured = stub_client(
        status_code: 200,
        response_body: '{"id":"pay_001","invoiceUrl":"https://asaas.com/i/pay_001"}'
      )

      result = client.create_payment(
        customer_id:        "cus_001",
        billing_type:       :pix,
        value:              25.0,
        due_date:           "2026-03-01",
        description:        "50 WhatsApp credits",
        external_reference: "credit_purchase_42"
      )

      assert_equal "pay_001",                        result["id"]
      assert_equal "https://asaas.com/i/pay_001",    result["invoiceUrl"]
      assert_kind_of Net::HTTP::Post, captured[:request]
      assert_includes captured[:request].path, "/payments"

      body = JSON.parse(captured[:request].body)
      assert_equal "cus_001",              body["customer"]
      assert_equal "PIX",                  body["billingType"]
      assert_equal 25.0,                   body["value"]
      assert_equal "2026-03-01",           body["dueDate"]
      assert_equal "50 WhatsApp credits",  body["description"]
      assert_equal "credit_purchase_42",   body["externalReference"]
    end

    test "create_payment raises ArgumentError for unknown billing_type" do
      client, = stub_client(status_code: 200, response_body: "{}")

      assert_raises(ArgumentError) do
        client.create_payment(
          customer_id: "cus_001", billing_type: :wire, value: 25.0,
          due_date: "2026-03-01", description: "credits", external_reference: "ref"
        )
      end
    end
  end
end
