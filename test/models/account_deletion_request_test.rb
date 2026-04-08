# frozen_string_literal: true

require "test_helper"

class AccountDeletionRequestTest < ActiveSupport::TestCase
  test "due returns only pending requests scheduled for execution" do
    due_request = users(:manager).account_deletion_requests.create!(
      status: :pending,
      requested_at: 8.days.ago,
      scheduled_for: 1.day.ago
    )
    future_request = users(:manager_two).account_deletion_requests.create!(
      status: :pending,
      requested_at: Time.current,
      scheduled_for: 2.days.from_now
    )
    completed_request = users(:secretary).account_deletion_requests.create!(
      status: :completed,
      requested_at: 9.days.ago,
      scheduled_for: 2.days.ago,
      completed_at: 1.day.ago
    )

    due_ids = AccountDeletionRequest.due.pluck(:id)

    assert_includes due_ids, due_request.id
    assert_not_includes due_ids, future_request.id
    assert_not_includes due_ids, completed_request.id
  end

  test "matching_identity finds requests by fingerprinted identifiers" do
    user = users(:manager)
    user.update_columns(phone_number: "+55 (11) 99999-0777", cpf_cnpj: "123.456.789-01", updated_at: Time.current)
    request = user.account_deletion_requests.create!(
      status: :completed,
      requested_at: 8.days.ago,
      scheduled_for: 1.day.ago,
      completed_at: Time.current,
      email_fingerprint: Security::AuditFingerprint.call(user.email, purpose: :email),
      name_fingerprint: Security::AuditFingerprint.call(user.name, purpose: :name),
      phone_fingerprint: Security::AuditFingerprint.call(user.phone_number, purpose: :phone_number),
      cpf_cnpj_fingerprint: Security::AuditFingerprint.call(user.cpf_cnpj, purpose: :cpf_cnpj)
    )

    assert_equal [ request.id ], AccountDeletionRequest.matching_identity("MANAGER@example.com").pluck(:id)
    assert_equal [ request.id ], AccountDeletionRequest.matching_identity("12345678901").pluck(:id)
    assert_equal [ request.id ], AccountDeletionRequest.matching_identity("5511999990777").pluck(:id)
    assert_equal [ request.id ], AccountDeletionRequest.matching_identity("dr. owner").pluck(:id)
  end
end
