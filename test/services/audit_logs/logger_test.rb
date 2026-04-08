# frozen_string_literal: true

require "test_helper"

module AuditLogs
  class EventLoggerTest < ActiveSupport::TestCase
    test "writes a user-scoped audit log with request context and subject fingerprints" do
      request = Struct.new(:request_id, :remote_ip, :fullpath).new("req-123", "203.0.113.9", "/profile/request_deletion")

      assert_difference "AuditLog.count", 1 do
        log = EventLogger.call(
          event_type: "privacy.deletion_requested",
          actor: users(:manager),
          space: spaces(:one),
          subject: users(:manager),
          request: request,
          metadata: { source: "profile_settings" }
        )

        assert_equal "privacy.deletion_requested", log.event_type
        assert_equal users(:manager), log.actor
        assert_equal spaces(:one), log.space
        assert_equal users(:manager), log.subject
        assert_equal "req-123", log.request_id
        assert_equal "203.0.113.9", log.ip_address
        assert_equal false, log.impersonated
        assert_equal Security::AuditFingerprint.call(users(:manager).email, purpose: :email), log.subject_email_fingerprint
        assert_equal Security::AuditFingerprint.call(users(:manager).name, purpose: :name), log.subject_name_fingerprint
      end
    end

    test "writes a customer-scoped audit log with impersonation context" do
      request = Struct.new(:request_id, :remote_ip, :fullpath).new("req-456", "198.51.100.25", "/customers/1")

      log = EventLogger.call(
        event_type: "privacy.customer_viewed",
        actor: users(:admin),
        space: spaces(:one),
        subject: customers(:one),
        request: request,
        impersonated: true,
        metadata: { surface: "platform_customer_show" }
      )

      assert_equal "privacy.customer_viewed", log.event_type
      assert log.impersonated
      assert_equal Security::AuditFingerprint.call(customers(:one).name, purpose: :name), log.subject_name_fingerprint
      assert_equal Security::AuditFingerprint.call(customers(:one).phone, purpose: :phone_number), log.subject_phone_fingerprint
    end
  end
end
