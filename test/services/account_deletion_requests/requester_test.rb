# frozen_string_literal: true

require "test_helper"

module AccountDeletionRequests
  class RequesterTest < ActiveSupport::TestCase
    setup do
      @user = users(:manager_two)
    end

    test "creates a pending deletion request with a 7 day grace period" do
      @user.update!(phone_number: "+5511999990888", cpf_cnpj: "12345678901")

      freeze_time do
        result = Requester.call(user: @user)

        assert result.success?
        assert_equal "pending", result.request.status
        assert_equal Time.current, result.request.requested_at
        assert_equal 7.days.from_now, result.request.scheduled_for
        assert_equal Security::AuditFingerprint.call(@user.email, purpose: :email), result.request.email_fingerprint
        assert_equal Security::AuditFingerprint.call(@user.name, purpose: :name), result.request.name_fingerprint
        assert_equal Security::AuditFingerprint.call(@user.phone_number, purpose: :phone_number), result.request.phone_fingerprint
        assert_equal Security::AuditFingerprint.call(@user.cpf_cnpj, purpose: :cpf_cnpj), result.request.cpf_cnpj_fingerprint
      end
    end

    test "returns existing pending request when one is already active" do
      existing = @user.account_deletion_requests.create!(
        status: :pending,
        requested_at: Time.current,
        scheduled_for: 7.days.from_now
      )

      result = Requester.call(user: @user)

      assert_not result.success?
      assert_equal existing, result.request
    end
  end
end
