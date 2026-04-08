# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", foreign_key: :actor_user_id, optional: true
  belongs_to :space, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :event_type, presence: true

  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  before_update { raise ActiveRecord::ReadOnlyRecord, "#{self.class} is append-only and cannot be updated" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "#{self.class} is append-only and cannot be destroyed" }

  def self.matching_subject(value)
    fingerprints = {
      subject_email_fingerprint: Security::AuditFingerprint.call(value, purpose: :email),
      subject_phone_fingerprint: Security::AuditFingerprint.call(value, purpose: :phone_number),
      subject_cpf_cnpj_fingerprint: Security::AuditFingerprint.call(value, purpose: :cpf_cnpj),
      subject_name_fingerprint: Security::AuditFingerprint.call(value, purpose: :name)
    }.compact

    return none if fingerprints.empty?

    first_column, first_value = fingerprints.first
    fingerprints.drop(1).reduce(where(first_column => first_value)) do |scope, (column, fingerprint)|
      scope.or(where(column => fingerprint))
    end
  end
end
