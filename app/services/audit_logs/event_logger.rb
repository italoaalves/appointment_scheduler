# frozen_string_literal: true

module AuditLogs
  class EventLogger
    def self.call(event_type:, actor: nil, space: nil, subject: nil, auditable: nil, request: nil, impersonated: false, metadata: {})
      new(
        event_type:,
        actor:,
        space:,
        subject:,
        auditable:,
        request:,
        impersonated:,
        metadata:
      ).call
    end

    def initialize(event_type:, actor:, space:, subject:, auditable:, request:, impersonated:, metadata:)
      @event_type = event_type
      @actor = actor
      @space = space
      @subject = subject
      @auditable = auditable
      @request = request
      @impersonated = impersonated
      @metadata = metadata
    end

    def call
      AuditLog.create!(
        event_type: @event_type,
        actor: @actor,
        space: @space,
        subject: subject_record,
        auditable: @auditable,
        request_id: @request&.request_id,
        ip_address: @request&.remote_ip,
        impersonated: @impersonated,
        metadata: normalized_metadata,
        **subject_fingerprints
      )
    end

    private

    def subject_record
      @subject if @subject.is_a?(ApplicationRecord)
    end

    def normalized_metadata
      (@metadata || {}).deep_stringify_keys
    end

    def subject_fingerprints
      attrs = subject_attributes

      {
        subject_email_fingerprint: Security::AuditFingerprint.call(attrs[:email], purpose: :email),
        subject_phone_fingerprint: Security::AuditFingerprint.call(attrs[:phone_number], purpose: :phone_number),
        subject_cpf_cnpj_fingerprint: Security::AuditFingerprint.call(attrs[:cpf_cnpj], purpose: :cpf_cnpj),
        subject_name_fingerprint: Security::AuditFingerprint.call(attrs[:name], purpose: :name)
      }.compact
    end

    def subject_attributes
      case @subject
      when User
        {
          email: @subject.email,
          phone_number: @subject.phone_number,
          cpf_cnpj: @subject.cpf_cnpj,
          name: @subject.name
        }
      when Customer
        {
          email: @subject.email,
          phone_number: @subject.phone,
          name: @subject.name
        }
      when Hash
        @subject.symbolize_keys.slice(:email, :phone_number, :cpf_cnpj, :name)
      else
        {}
      end
    end
  end
end
