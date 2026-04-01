# frozen_string_literal: true

module Spaces
  class WhatsappSettingsController < BaseController
    include RequirePermission

    require_permission :manage_space, redirect_to: :root_path

    def show
      @phone_number = current_tenant.whatsapp_phone_number
    end

    def connect
      phone_number = current_tenant.build_whatsapp_phone_number(connect_params)
      phone_number.status = :active

      if phone_number.save
        redirect_to settings_whatsapp_path, notice: t("spaces.whatsapp_settings.connected")
      else
        redirect_to settings_whatsapp_path, alert: phone_number.errors.full_messages.to_sentence
      end
    end

    def disconnect
      phone_number = current_tenant.whatsapp_phone_number

      if phone_number&.update(status: :disconnected)
        redirect_to settings_whatsapp_path, notice: t("spaces.whatsapp_settings.disconnected")
      else
        redirect_to settings_whatsapp_path, alert: t("spaces.whatsapp_settings.disconnect_failed")
      end
    end

    private

    def connect_params
      params.require(:whatsapp_phone_number).permit(:phone_number_id, :display_number, :waba_id, :verified_name)
    end
  end
end
