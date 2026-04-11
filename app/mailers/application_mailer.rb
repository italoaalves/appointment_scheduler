class ApplicationMailer < ActionMailer::Base
  default from: -> { MailerConfiguration.sender }
  layout "mailer"
  helper MailerHelper

  private

  def with_mail_locale(locale = nil, recipient: nil, fallback_space: nil, &block)
    resolved_locale = LocaleResolver.normalize(locale) ||
      LocaleResolver.recipient(recipient, fallback_space:) ||
      I18n.default_locale.to_s

    I18n.with_locale(resolved_locale, &block)
  end
end
