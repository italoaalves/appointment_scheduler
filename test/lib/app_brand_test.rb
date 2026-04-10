# frozen_string_literal: true

require "test_helper"

class AppBrandTest < ActiveSupport::TestCase
  test "uses config app settings when present" do
    app_config = OpenStruct.new(
      x: ordered_options(
        app: ordered_options(
          name: "Configured Name",
          legal_product_name: "Configured Legal Name",
          authenticator_name: "Configured Auth",
          logo_asset: "configured-logo.png",
          wordmark_asset: "configured-wordmark.png"
        )
      )
    )

    settings = AppBrand.settings(app_config:, credentials: {})

    assert_equal "Configured Name", settings[:name]
    assert_equal "Configured Legal Name", settings[:legal_product_name]
    assert_equal "Configured Auth", settings[:authenticator_name]
    assert_equal "configured-logo.png", settings[:logo_asset]
    assert_equal "configured-wordmark.png", settings[:wordmark_asset]
  end

  test "falls back to credential app settings when config app settings are absent" do
    app_config = OpenStruct.new(x: ordered_options)
    credentials = {
      app: {
        name: "Credential Name",
        authenticator_name: "Credential Auth"
      }
    }

    settings = AppBrand.settings(app_config:, credentials:)

    assert_equal "Credential Name", settings[:name]
    assert_equal "Credential Name", settings[:legal_product_name]
    assert_equal "Credential Auth", settings[:authenticator_name]
  end

  test "falls back to defaults when no app settings exist" do
    settings = AppBrand.settings(app_config: OpenStruct.new(x: ordered_options), credentials: {})

    assert_equal "Anella", settings[:name]
    assert_equal "Anella", settings[:legal_product_name]
    assert_equal "Anella", settings[:authenticator_name]
  end

  private

  def ordered_options(**values)
    ActiveSupport::OrderedOptions.new.tap do |options|
      values.each do |key, value|
        options[key] = value
      end
    end
  end
end
