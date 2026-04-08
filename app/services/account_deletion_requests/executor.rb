# frozen_string_literal: true

module AccountDeletionRequests
  class Executor
    Result = Struct.new(:success?, :request, :error, keyword_init: true)

    def self.call(request:)
      new(request:).call
    end

    def initialize(request:)
      @request = request
    end

    def call
      @request.with_lock do
        @request.reload

        return Result.new(success?: false, request: @request, error: :already_processed) unless @request.pending?
        return Result.new(success?: false, request: @request, error: :not_due) unless due?

        @request.user.with_lock do
          persist_audit_fingerprints!
          revoke_access!
          anonymize_user!
          complete_request!
        end
      end

      Result.new(success?: true, request: @request)
    end

    private

    def due?
      @request.scheduled_for <= Time.current
    end

    def user
      @user ||= @request.user
    end

    def persist_audit_fingerprints!
      @request.update!(
        email_fingerprint: @request.email_fingerprint.presence || Security::AuditFingerprint.call(user.email, purpose: :email),
        name_fingerprint: @request.name_fingerprint.presence || Security::AuditFingerprint.call(user.name, purpose: :name),
        phone_fingerprint: @request.phone_fingerprint.presence || Security::AuditFingerprint.call(user.phone_number, purpose: :phone_number),
        cpf_cnpj_fingerprint: @request.cpf_cnpj_fingerprint.presence || Security::AuditFingerprint.call(user.cpf_cnpj, purpose: :cpf_cnpj)
      )
    end

    def revoke_access!
      now = Time.current

      Space.where(owner_id: user.id).update_all(owner_id: nil, updated_at: now)
      Customer.where(user_id: user.id).update_all(user_id: nil, updated_at: now)
      Conversation.where(assigned_to_id: user.id).update_all(assigned_to_id: nil, updated_at: now)
      ConversationMessage.where(sent_by_id: user.id).update_all(sent_by_id: nil, updated_at: now)
      WhatsappMessage.where(sent_by_id: user.id).update_all(sent_by_id: nil, updated_at: now)

      Notification.where(user_id: user.id).delete_all
      UserPermission.where(user_id: user.id).delete_all
      UserPreference.where(user_id: user.id).delete_all
      SpaceMembership.where(user_id: user.id).delete_all
    end

    def anonymize_user!
      user.update_columns(
        email: anonymized_email,
        name: "Deleted User #{user.id}",
        phone_number: nil,
        cpf_cnpj: nil,
        encrypted_password: Devise::Encryptor.digest(User, SecureRandom.hex(32)),
        role: "",
        system_role: nil,
        confirmed_at: nil,
        confirmation_sent_at: nil,
        confirmation_token: nil,
        unconfirmed_email: nil,
        remember_created_at: nil,
        reset_password_token: nil,
        reset_password_sent_at: nil,
        updated_at: Time.current
      )
    end

    def complete_request!
      @request.update!(status: :completed, completed_at: Time.current)
    end

    def anonymized_email
      "deleted-user-#{user.id}-#{@request.id}@deleted.invalid"
    end
  end
end
