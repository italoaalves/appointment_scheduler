# frozen_string_literal: true

class DeviseMailer < Devise::Mailer
  private

  def devise_mail(record, action, opts = {}, &block)
    I18n.with_locale(LocaleResolver.recipient(record)) do
      super(record, action, opts, &block)
    end
  end
end
