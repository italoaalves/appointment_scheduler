# frozen_string_literal: true

require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @user = users(:manager)
    @user.create_user_preference!(locale: "en") unless @user.user_preference
  end

  test "submitting forgot password sends reset instructions" do
    assert_emails 1 do
      post user_password_path,
        params: { user: { email: @user.email } },
        headers: { "Accept-Language" => "pt-BR,pt;q=0.9" }
    end

    assert_redirected_to new_user_session_path

    email = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email ], email.to
    assert_equal I18n.with_locale("en") { I18n.t("devise.mailer.reset_password_instructions.subject") }, email.subject
    assert_includes email.body.encoded, "Reset your password"
  end
end
