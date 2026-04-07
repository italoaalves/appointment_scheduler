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
