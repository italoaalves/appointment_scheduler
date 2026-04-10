class ApplicationMailer < ActionMailer::Base
  default from: -> { MailerConfiguration.sender }
  layout "mailer"
end
