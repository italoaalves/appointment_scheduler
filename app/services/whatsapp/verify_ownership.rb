# frozen_string_literal: true

module Whatsapp
  class VerifyOwnership
    Result = Data.define(:success?, :error)

    def initialize(client: nil)
      @client = client
    end

    def call(phone_number_id:, waba_id:)
      response = fetch_phone_number(phone_number_id)

      unless response["id"] == phone_number_id
        return Result.new(success?: false, error: "Phone number ID mismatch")
      end

      response_waba = response.dig("whatsapp_business_account", "id") || response["waba_id"]
      unless response_waba == waba_id
        return Result.new(success?: false, error: "WABA ID mismatch")
      end

      Result.new(success?: true, error: nil)
    rescue Whatsapp::Client::ApiError => e
      Result.new(success?: false, error: e.message)
    rescue StandardError => e
      Rails.logger.error("[Whatsapp::VerifyOwnership] Unexpected error: #{e.message}")
      Result.new(success?: false, error: "Verification failed")
    end

    private

    def fetch_phone_number(phone_number_id)
      uri = URI("#{Whatsapp::Client::BASE_URL}/#{phone_number_id}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body)
    end

    def access_token
      Rails.application.credentials.dig(:whatsapp, :access_token)
    end
  end
end
