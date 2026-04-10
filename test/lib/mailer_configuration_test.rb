# frozen_string_literal: true

require "test_helper"

class MailerConfigurationTest < ActiveSupport::TestCase
  test "builds sender and url options from app base url when mailer credentials are absent" do
    credentials = ActiveSupport::InheritableOptions.new(
      app: {
        base_url: "https://staging.anella.app"
      }
    )

    assert_equal "noreply@staging.anella.app", MailerConfiguration.sender(credentials: credentials)
    assert_equal(
      { host: "staging.anella.app", protocol: "https" },
      MailerConfiguration.default_url_options(force_ssl: true, credentials: credentials)
    )
  end

  test "prefers explicit mailer credentials over app base url" do
    credentials = ActiveSupport::InheritableOptions.new(
      app: {
        base_url: "https://staging.anella.app"
      },
      mailer: {
        from: "support@anella.app",
        host: "mail.anella.app",
        protocol: "https",
        port: 8443
      }
    )

    assert_equal "support@anella.app", MailerConfiguration.sender(credentials: credentials)
    assert_equal(
      { host: "mail.anella.app", protocol: "https", port: 8443 },
      MailerConfiguration.default_url_options(force_ssl: true, credentials: credentials)
    )
  end
end
