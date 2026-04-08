# frozen_string_literal: true

module AccountDeletionRequests
  class Requester
    Result = Struct.new(:success?, :request, :error, keyword_init: true)

    GRACE_PERIOD = 7.days

    def self.call(user:, actor: nil, request: nil, metadata: {})
      new(user:, actor:, request:, metadata:).call
    end

    def initialize(user:, actor:, request:, metadata:)
      @user = user
      @actor = actor
      @request = request
      @metadata = metadata
    end

    def call
      existing_request = @user.account_deletion_requests.active.first
      return Result.new(success?: false, request: existing_request, error: :already_requested) if existing_request

      request = @user.account_deletion_requests.create!(
        status: :pending,
        requested_at: Time.current,
        scheduled_for: Time.current + GRACE_PERIOD,
        email_fingerprint: Security::AuditFingerprint.call(@user.email, purpose: :email),
        name_fingerprint: Security::AuditFingerprint.call(@user.name, purpose: :name),
        phone_fingerprint: Security::AuditFingerprint.call(@user.phone_number, purpose: :phone_number),
        cpf_cnpj_fingerprint: Security::AuditFingerprint.call(@user.cpf_cnpj, purpose: :cpf_cnpj)
      )

      AuditLogs::EventLogger.call(
        event_type: "privacy.deletion_requested",
        actor: @actor,
        space: @user.space,
        subject: @user,
        auditable: request,
        request: @request,
        impersonated: @metadata[:impersonated] || false,
        metadata: @metadata.except(:impersonated)
      )

      Result.new(success?: true, request:)
    end
  end
end
