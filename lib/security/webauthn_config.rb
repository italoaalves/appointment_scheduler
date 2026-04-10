# frozen_string_literal: true

require "uri"
require_relative "../app_brand"

module Security
  class WebauthnConfig
    class ConfigurationError < StandardError; end

    class << self
      def configure!
        settings = resolved_settings

        WebAuthn.configure do |config|
          config.allowed_origins = settings.fetch(:allowed_origins)
          config.rp_id = settings.fetch(:rp_id)
          config.rp_name = settings.fetch(:rp_name)
        end
      end

      def resolved_settings(
        credentials: Rails.application.credentials,
        webauthn_config: Rails.application.config.x.webauthn,
        app_config: Rails.application.config,
        env: ENV,
        default_rp_name: AppBrand.authenticator_name(app_config:, credentials:)
      )
        webauthn_credentials = credentials.dig(:webauthn) || {}

        allowed_origins =
          normalize_origins(webauthn_config.allowed_origins).presence ||
            normalize_origins(webauthn_credentials[:allowed_origins]).presence ||
            normalize_origins(env["WEBAUTHN_ALLOWED_ORIGINS"]).presence ||
            derived_origins(credentials:, app_config:)

        if allowed_origins.blank?
          raise ConfigurationError,
                "Configure WebAuthn allowed origins via config.x.webauthn.allowed_origins, " \
                "credentials.webauthn.allowed_origins, ENV[WEBAUTHN_ALLOWED_ORIGINS], " \
                "or app.base_url/app.base_urls."
        end

        rp_id = webauthn_config.rp_id.presence || webauthn_credentials[:rp_id].presence || env["WEBAUTHN_RP_ID"].presence

        if rp_id.blank?
          if allowed_origins.one?
            rp_id = URI.parse(allowed_origins.first).host
          else
            raise ConfigurationError, "Configure WebAuthn rp_id explicitly when multiple allowed origins are used."
          end
        end

        rp_name =
          webauthn_config.rp_name.presence ||
            webauthn_credentials[:rp_name].presence ||
            env["WEBAUTHN_RP_NAME"].presence ||
            default_rp_name

        {
          allowed_origins: allowed_origins,
          rp_id: rp_id,
          rp_name: rp_name
        }
      end

      private

      def derived_origins(credentials:, app_config:)
        app_credentials = credentials.dig(:app) || {}
        app_settings = app_config.x.respond_to?(:app) ? app_config.x.app : nil

        normalize_origins(app_settings&.base_urls).presence ||
          normalize_origins(app_settings&.base_url).presence ||
          normalize_origins(app_credentials[:base_urls]).presence ||
          normalize_origins(app_credentials[:base_url]).presence ||
          normalize_origins(default_url_origin(app_config)).presence
      end

      def default_url_origin(app_config)
        mailer_options = app_config.action_mailer.default_url_options || {}
        host = mailer_options[:host].presence
        return if host.blank?

        protocol = mailer_options[:protocol].presence || (app_config.force_ssl ? "https" : "http")
        port = mailer_options[:port].presence

        "#{protocol}://#{host}#{port.present? ? ":#{port}" : ''}"
      end

      def normalize_origins(value)
        items =
          case value
          when nil then []
          when String then value.split(",")
          else Array(value)
          end

        items.filter_map { |origin| origin.to_s.strip.presence }.uniq
      end
    end
  end
end
