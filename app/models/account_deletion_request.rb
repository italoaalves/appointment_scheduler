# frozen_string_literal: true

class AccountDeletionRequest < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, canceled: 1, completed: 2 }, default: :pending

  validates :requested_at, :scheduled_for, :status, presence: true

  scope :active, -> { pending.order(requested_at: :desc) }
  scope :due, -> { pending.where(scheduled_for: ..Time.current).order(scheduled_for: :asc, id: :asc) }

  def self.matching_identity(value)
    fingerprints = {
      email_fingerprint: Security::AuditFingerprint.call(value, purpose: :email),
      phone_fingerprint: Security::AuditFingerprint.call(value, purpose: :phone_number),
      cpf_cnpj_fingerprint: Security::AuditFingerprint.call(value, purpose: :cpf_cnpj),
      name_fingerprint: Security::AuditFingerprint.call(value, purpose: :name)
    }.compact

    return none if fingerprints.empty?

    first_column, first_value = fingerprints.first
    fingerprints.drop(1).reduce(where(first_column => first_value)) do |scope, (column, fingerprint)|
      scope.or(where(column => fingerprint))
    end.order(requested_at: :desc)
  end
end
