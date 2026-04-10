class ApplicationMailer < ActionMailer::Base
  default from: -> { MailerConfiguration.sender }
  layout "mailer"
  helper MailerHelper
end
