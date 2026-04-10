require_relative "boot"

require "rails/all"
require_relative "../lib/action_mailer/delivery_methods/resend_api"

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
