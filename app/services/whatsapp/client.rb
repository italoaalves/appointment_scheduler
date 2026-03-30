# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Whatsapp
  class Client
    BASE_URL = "https://graph.facebook.com/v22.0"

    class ApiError < StandardError
      attr_reader :status, :error_data

      def initialize(message, status: nil, error_data: nil)
        @status     = status
        @error_data = error_data
        super(message)
      end
    end

    def initialize(phone_number_id: nil, access_token: nil, http_adapter: nil)
      @phone_number_id = phone_number_id || default_phone_number_id
      @access_token    = access_token    || default_access_token
      @http_adapter    = http_adapter
    end

    def send_template(to:, template_name:, language: "pt_BR", components: [])
      post_message(
        to:       normalize_phone(to),
        type:     "template",
        template: {
          name:       template_name,
          language:   { code: language },
          components: components
        }
      )
    end

    def send_text(to:, body:)
      post_message(
        to:   normalize_phone(to),
        type: "text",
        text: { body: body }
      )
    end

    def mark_as_read(message_id:)
      post(messages_url, {
        messaging_product: "whatsapp",
        status:            "read",
        message_id:        message_id
      })
    end

    private

    def post_message(to:, type:, **payload)
      post(messages_url, {
        messaging_product: "whatsapp",
        recipient_type:    "individual",
        to:                to,
        type:              type,
        **payload
      })
    end

    def messages_url
      "#{BASE_URL}/#{@phone_number_id}/messages"
    end

    def post(url, body)
      uri     = URI(url)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request["Content-Type"]  = "application/json"
      request.body              = body.to_json

      response = perform_request(uri, request)
      parsed   = JSON.parse(response.body)

      unless (200..299).cover?(response.code.to_i)
        error_msg = parsed.dig("error", "message") || "Unknown API error"
        raise ApiError.new(error_msg, status: response.code.to_i, error_data: parsed["error"])
      end

      parsed
    end

    def perform_request(uri, request)
      return @http_adapter.call(request) if @http_adapter

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def normalize_phone(phone)
      phone.to_s.gsub(/\D/, "")
    end

    def default_phone_number_id
      Rails.application.credentials.dig(:whatsapp, :phone_number_id)
    end

    def default_access_token
      Rails.application.credentials.dig(:whatsapp, :access_token)
    end
  end
end
