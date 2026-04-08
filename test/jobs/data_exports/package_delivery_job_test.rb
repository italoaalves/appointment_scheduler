# frozen_string_literal: true

require "test_helper"

module DataExports
  class PackageDeliveryJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    setup do
      ActionMailer::Base.deliveries.clear
      @manager = users(:manager)
      @manager.create_user_preference!(locale: "pt-BR") unless @manager.user_preference
    end

    test "sends the export package to the user's email" do
      assert_emails 1 do
        PackageDeliveryJob.perform_now(@manager.id)
      end

      email = ActionMailer::Base.deliveries.last
      attachment = email.attachments.first

      assert_equal [ @manager.email ], email.to
      assert_equal I18n.t("data_exports.package_mailer.export_ready.subject"), email.subject
      assert_not_nil attachment
      assert_includes attachment.filename, "lgpd-export"
      assert_includes attachment.content_type, "application/zip"
    end

    test "does nothing when the user no longer exists" do
      assert_no_emails do
        PackageDeliveryJob.perform_now(-1)
      end
    end
  end
end
