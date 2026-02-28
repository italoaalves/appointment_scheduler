# frozen_string_literal: true

require "test_helper"

class ImpersonationTest < ActionDispatch::IntegrationTest
  setup do
    @admin   = users(:admin)
    @manager = users(:manager)
  end

  # ── HEAD verb confusion ────────────────────────────────────────────────────
  #
  # HEAD is routed identically to GET but `request.get?` returns false.
  # `audit_impersonation_write` must skip audit logging for HEAD (read-like),
  # otherwise every HEAD request while impersonating pollutes the audit trail
  # with false "write_action=true" entries.

  test "HEAD request while impersonating does NOT produce a write audit log entry" do
    sign_in @admin
    post impersonate_platform_user_url(@manager)
    assert session[:impersonated_user_id], "Impersonation session must be active"

    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output)

    head appointments_url

    Rails.logger = old_logger

    assert_no_match(/\[IMPERSONATION\] write_action=true/, log_output.string,
      "HEAD request must not be logged as a write action during impersonation")
  end

  test "POST request while impersonating DOES produce a write audit log entry" do
    sign_in @admin
    post impersonate_platform_user_url(@manager)
    assert session[:impersonated_user_id], "Impersonation session must be active"

    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output)

    post customers_url, params: { customer: { name: "Test", phone: "+5511999999999" } }

    Rails.logger = old_logger

    assert_match(/\[IMPERSONATION\] write_action=true/, log_output.string,
      "POST request must be logged as a write action during impersonation")
  end
end
