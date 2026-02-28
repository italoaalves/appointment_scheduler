# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Billing
  class AsaasClient
    class ApiError < StandardError
      attr_reader :status_code, :body

      def initialize(status_code, body)
        @status_code = status_code
        @body        = body
        super("Asaas API error #{status_code}: #{body}")
      end
    end

    BILLING_TYPES = {
      pix:         "PIX",
      credit_card: "CREDIT_CARD",
      boleto:      "BOLETO"
    }.freeze

    def initialize(http_adapter: nil)
      credentials = Rails.application.credentials.asaas || {}
      @api_key      = credentials[:api_key].to_s.freeze
      @base_url     = (credentials[:base_url].presence || "https://sandbox.asaas.com/api/v3").freeze
      @http_adapter = http_adapter
    end

    # ── Customers ─────────────────────────────────────────────────────────────

    def create_customer(name:, email:, cpf_cnpj:, external_reference:)
      post("/customers", {
        name:              name,
        email:             email,
        cpfCnpj:           cpf_cnpj,
        externalReference: external_reference
      })
    end

    def find_customer(asaas_customer_id)
      get("/customers/#{asaas_customer_id}")
    end

    # ── Subscriptions ──────────────────────────────────────────────────────────

    def create_subscription(customer_id:, billing_type:, value:, next_due_date:,
                            cycle: "MONTHLY", description:, external_reference:)
      post("/subscriptions", {
        customer:          customer_id,
        billingType:       map_billing_type(billing_type),
        value:             value,
        nextDueDate:       next_due_date,
        cycle:             cycle,
        description:       description,
        externalReference: external_reference
      })
    end

    def update_subscription(asaas_subscription_id, attrs)
      put("/subscriptions/#{asaas_subscription_id}", attrs)
    end

    def cancel_subscription(asaas_subscription_id)
      delete("/subscriptions/#{asaas_subscription_id}")
    end

    def find_subscription(asaas_subscription_id)
      get("/subscriptions/#{asaas_subscription_id}")
    end

    # ── Payments ──────────────────────────────────────────────────────────────

    def create_payment(customer_id:, billing_type:, value:, due_date:, description:, external_reference:)
      post("/payments", {
        customer:          customer_id,
        billingType:       map_billing_type(billing_type),
        value:             value,
        dueDate:           due_date,
        description:       description,
        externalReference: external_reference
      })
    end

    def find_payment(asaas_payment_id)
      get("/payments/#{asaas_payment_id}")
    end

    def list_payments(subscription_id:)
      get("/payments", { subscription: subscription_id })
    end

    private

    def map_billing_type(billing_type)
      BILLING_TYPES.fetch(billing_type.to_sym) do
        raise ArgumentError, "Unknown billing_type: #{billing_type.inspect}. Valid: #{BILLING_TYPES.keys.join(', ')}"
      end
    end

    def post(path, payload)
      execute(:post, path, payload)
    end

    def put(path, payload)
      execute(:put, path, payload)
    end

    def get(path, params = {})
      execute(:get, path, nil, params)
    end

    def delete(path)
      execute(:delete, path)
    end

    def execute(method, path, payload = nil, params = {})
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?

      req = build_request(method, uri)
      req.body = payload.to_json if payload

      handle_response(perform_request(uri, req))
    end

    def perform_request(uri, req)
      return @http_adapter.call(req) if @http_adapter

      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: 10,
                      read_timeout: 30) do |http|
        http.request(req)
      end
    end

    def build_request(method, uri)
      klass = case method
      when :post   then Net::HTTP::Post
      when :get    then Net::HTTP::Get
      when :put    then Net::HTTP::Put
      when :delete then Net::HTTP::Delete
      end

      req = klass.new(uri)
      req["access-token"] = @api_key
      req["Content-Type"]  = "application/json"
      req["Accept"]        = "application/json"
      req
    end

    def handle_response(response)
      code = response.code.to_i
      body = response.body.to_s

      raise ApiError.new(code, body) unless code.between?(200, 299)

      body.empty? ? {} : JSON.parse(body)
    end
  end
end
