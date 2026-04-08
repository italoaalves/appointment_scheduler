# frozen_string_literal: true

require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  def valid_attrs
    {
      event_type: "privacy.export_requested",
      actor: users(:manager),
      space: spaces(:one),
      metadata: { source: "profile_settings" }
    }
  end

  test "audit log can be created" do
    log = AuditLog.create!(valid_attrs)

    assert log.persisted?
  end

  test "event_type is required" do
    log = AuditLog.new(valid_attrs.merge(event_type: nil))

    assert_not log.valid?
    assert log.errors[:event_type].any?
  end

  test "persisted audit logs cannot be updated" do
    log = AuditLog.create!(valid_attrs)

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      log.update!(event_type: "privacy.export_delivered")
    end
  end

  test "persisted audit logs cannot be destroyed" do
    log = AuditLog.create!(valid_attrs)

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      log.destroy!
    end
  end

  test "matching_subject finds logs by normalized fingerprint" do
    log = AuditLog.create!(
      valid_attrs.merge(
        subject_name_fingerprint: Security::AuditFingerprint.call("John Customer", purpose: :name),
        subject_phone_fingerprint: Security::AuditFingerprint.call("+55 (11) 88888-8888", purpose: :phone_number)
      )
    )

    assert_equal [ log.id ], AuditLog.matching_subject("john customer").pluck(:id)
    assert_equal [ log.id ], AuditLog.matching_subject("5511888888888").pluck(:id)
  end
end
