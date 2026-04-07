# frozen_string_literal: true

module Platform
  class IntegrationsController < BaseController
    # GET /platform/integrations
    def index
      @meta_credentials = {
        access_token: credential(:meta, :access_token),
        app_secret: credential(:meta, :app_secret),
        verify_token: credential(:meta, :verify_token),
        whatsapp_phone_number_id: credential(:meta, :whatsapp, :phone_number_id)
      }
    end

    # POST /platform/integrations/whatsapp_check
    def whatsapp_check
      access_token    = Rails.application.credentials.dig(:meta, :access_token)
      phone_number_id = Rails.application.credentials.dig(:meta, :whatsapp, :phone_number_id)

      if access_token.blank? || phone_number_id.blank?
        redirect_to platform_integrations_path, alert: t("platform.integrations.whatsapp.check_missing_credentials")
        return
      end

      uri = URI("#{Whatsapp::Client::BASE_URL}/#{phone_number_id}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      parsed = JSON.parse(response.body)

      if parsed["error"]
        redirect_to platform_integrations_path, alert: t("platform.integrations.whatsapp.check_failed",
          error: parsed.dig("error", "message"))
      else
        display_name = parsed["verified_name"] || parsed["display_phone_number"] || phone_number_id
        redirect_to platform_integrations_path, notice: t("platform.integrations.whatsapp.check_ok",
          name: display_name, phone: parsed["display_phone_number"])
      end
    rescue StandardError => e
      redirect_to platform_integrations_path, alert: t("platform.integrations.whatsapp.check_failed", error: e.message)
    end

    # POST /platform/integrations/whatsapp_test
    def whatsapp_test
      phone = params[:phone]&.strip
      if phone.blank?
        redirect_to platform_integrations_path, alert: t("platform.integrations.whatsapp.phone_required")
        return
      end

      client = Whatsapp::Client.new
      response = client.send_text(to: phone, body: t("platform.integrations.whatsapp.test_message_body"))
      redirect_to platform_integrations_path, notice: t("platform.integrations.whatsapp.test_sent", wamid: response.dig("messages", 0, "id"))
    rescue Whatsapp::Client::ApiError => e
      redirect_to platform_integrations_path, alert: t("platform.integrations.whatsapp.test_failed", error: e.message)
    end

    private

    def credential(*keys)
      Rails.application.credentials.dig(*keys).present?
    end
  end
end
