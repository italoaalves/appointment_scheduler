# frozen_string_literal: true

module AppBrand
  DEFAULTS = {
    name: "Anella",
    legal_product_name: nil,
    authenticator_name: nil,
    company_name: "Elo Consultoria em Software LTDA",
    support_email: nil,
    logo_asset: "anella-logo.png",
    wordmark_asset: "anela-bgless.png"
  }.freeze

  module_function

  def settings(app_config: Rails.application.config, credentials: Rails.application.credentials)
    config_settings = normalize_settings(app_config.x.respond_to?(:app) ? app_config.x.app : nil)
    credential_settings = normalize_settings(credentials.dig(:app))

    merged = DEFAULTS.merge(credential_settings).merge(config_settings)
    merged[:legal_product_name] = merged[:legal_product_name].presence || merged[:name]
    merged[:authenticator_name] = merged[:authenticator_name].presence || merged[:name]
    merged[:logo_asset] = merged[:logo_asset].presence || DEFAULTS[:logo_asset]
    merged[:wordmark_asset] = merged[:wordmark_asset].presence || DEFAULTS[:wordmark_asset]
    merged
  end

  def name(...)
    settings(...).fetch(:name)
  end

  def legal_product_name(...)
    settings(...).fetch(:legal_product_name)
  end

  def authenticator_name(...)
    settings(...).fetch(:authenticator_name)
  end

  def company_name(...)
    settings(...).fetch(:company_name)
  end

  def support_email(...)
    settings(...).fetch(:support_email)
  end

  def logo_asset(...)
    settings(...).fetch(:logo_asset)
  end

  def wordmark_asset(...)
    settings(...).fetch(:wordmark_asset)
  end

  def normalize_settings(source)
    case source
    when nil
      {}
    when ActiveSupport::OrderedOptions
      source.to_h.symbolize_keys
    else
      source.to_h.symbolize_keys
    end
  rescue NoMethodError
    {}
  end
  private_class_method :normalize_settings
end
