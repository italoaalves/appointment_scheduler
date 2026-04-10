require_relative "boot"

require "rails/all"
require_relative "../lib/action_mailer/delivery_methods/resend_api"
require_relative "../lib/mailer_configuration"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AppointmentScheduler
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Tailwind builds into app/assets/builds; register it explicitly so
    # clean Docker build contexts still include tailwind.css in Propshaft.
    config.assets.paths << Rails.root.join("app/assets/builds")
    ActionMailer::Base.add_delivery_method :resend_api, ActionMailer::DeliveryMethods::ResendApi

    # Internationalization
    config.i18n.available_locales = [ :en, :'pt-BR' ]
    config.i18n.default_locale = :'pt-BR'
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.yml")]

    app_credentials = Rails.application.credentials.dig(:app) || {}
    config.x.app.name = ENV["APP_NAME"].presence || app_credentials[:name].presence || "Anella"
    config.x.app.legal_product_name = ENV["APP_LEGAL_PRODUCT_NAME"].presence || app_credentials[:legal_product_name].presence || config.x.app.name
    config.x.app.authenticator_name = ENV["APP_AUTHENTICATOR_NAME"].presence || app_credentials[:authenticator_name].presence || config.x.app.name
    config.x.app.company_name = ENV["APP_COMPANY_NAME"].presence || app_credentials[:company_name].presence || "Elo Consultoria em Software LTDA"
    config.x.app.support_email = ENV["APP_SUPPORT_EMAIL"].presence || app_credentials[:support_email].presence
    config.x.app.logo_asset = ENV["APP_LOGO_ASSET"].presence || app_credentials[:logo_asset].presence || "anella-logo.png"
    config.x.app.wordmark_asset = ENV["APP_WORDMARK_ASSET"].presence || app_credentials[:wordmark_asset].presence || "anela-bgless.png"
    config.x.app.base_url = ENV["APP_BASE_URL"].presence || app_credentials[:base_url].presence
    config.x.app.base_urls = if ENV["APP_BASE_URLS"].present?
      ENV["APP_BASE_URLS"].split(",").map(&:strip).reject(&:blank?)
    else
      Array(app_credentials[:base_urls]).presence
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
