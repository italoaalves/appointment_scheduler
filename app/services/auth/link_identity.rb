# frozen_string_literal: true

module Auth
  class LinkIdentity
    Result = Struct.new(:success?, :identity, :error, keyword_init: true)

    def self.call(user:, provider:, uid:, email:, email_verified:, metadata: {})
      new(
        user:,
        provider:,
        uid:,
        email:,
        email_verified:,
        metadata:
      ).call
    end

    def initialize(user:, provider:, uid:, email:, email_verified:, metadata:)
      @user = user
      @provider = provider.to_s
      @uid = uid.to_s
      @email = email.presence
      @email_verified = ActiveModel::Type::Boolean.new.cast(email_verified)
      @metadata = metadata.deep_stringify_keys
    end

    def call
      existing_identity = UserIdentity.find_by(provider: @provider, uid: @uid)
      return Result.new(success?: false, error: :identity_conflict) if existing_identity.present? && existing_identity.user_id != @user.id

      identity = @user.user_identities.find_or_initialize_by(provider: @provider)
      return Result.new(success?: false, error: :provider_already_linked) if identity.persisted? && identity.uid != @uid

      identity.uid = @uid
      identity.email = @email
      identity.email_verified = @email_verified
      identity.metadata = @metadata
      identity.last_authenticated_at = Time.current
      identity.save!

      Result.new(success?: true, identity:)
    rescue ActiveRecord::RecordNotUnique
      Result.new(success?: false, error: :identity_conflict)
    end
  end
end
