# frozen_string_literal: true

module DataExports
  class PackageMailer < ApplicationMailer
    def export_ready(user_id:)
      @user = User.find(user_id)
      with_mail_locale(recipient: @user) do
        package = DataExports::PackageBuilder.call(user: @user)

        attachments[package.filename] = {
          mime_type: package.content_type,
          content: package.data
        }

        mail(
          to: @user.email,
          subject: I18n.t("data_exports.package_mailer.export_ready.subject")
        )
      end
    end
  end
end
