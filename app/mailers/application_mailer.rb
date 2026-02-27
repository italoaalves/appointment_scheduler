class ApplicationMailer < ActionMailer::Base
  default from: -> {
    Rails.application.credentials.dig(:mailer, :from) ||
      "noreply@#{Rails.application.credentials.dig(:mailer, :domain) || 'example.com'}"
  }
  layout "mailer"
end
