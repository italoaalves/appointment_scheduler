# frozen_string_literal: true

require "test_helper"

module Platform
  class AuditLogsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @manager = users(:manager)
    end

    test "admin can list audit logs" do
      AuditLog.create!(
        event_type: "privacy.export_requested",
        actor: @manager,
        space: spaces(:one),
        subject: customers(:one),
        subject_name_fingerprint: Security::AuditFingerprint.call(customers(:one).name, purpose: :name)
      )

      sign_in @admin
      get platform_audit_logs_url

      assert_response :success
      assert_select "table"
      assert_select "td", text: "privacy.export_requested"
    end

    test "admin can search audit logs by person identifier" do
      matching = AuditLog.create!(
        event_type: "privacy.customer_viewed",
        actor: @manager,
        space: spaces(:one),
        subject: customers(:one),
        subject_name_fingerprint: Security::AuditFingerprint.call(customers(:one).name, purpose: :name)
      )
      AuditLog.create!(
        event_type: "authorization.permission_denied",
        actor: users(:manager_two),
        space: spaces(:two),
        subject_name_fingerprint: Security::AuditFingerprint.call("Someone Else", purpose: :name)
      )

      sign_in @admin
      get platform_audit_logs_url, params: { query: "john customer" }

      assert_response :success
      assert_select "td", text: matching.event_type
      assert_select "td", text: spaces(:one).name
      assert_select "td", text: spaces(:two).name, count: 0
    end

    test "non-admin is redirected" do
      sign_in @manager

      get platform_audit_logs_url

      assert_redirected_to root_url
    end
  end
end
