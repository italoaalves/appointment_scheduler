# frozen_string_literal: true

module Auth
  class ResolveIdentityFromOmniauth
    Result = Struct.new(:outcome, :user, :identity, :provider, :email, :name, :error, :linked, keyword_init: true)

    def self.call(auth:, session:, current_user: nil)
      new(auth:, session:, current_user:).call
    end

    def initialize(auth:, session:, current_user:)
      @auth = auth
      @session = session
      @current_user = current_user
    end

    def call
      return failure(:invalid_auth) if provider.blank? || uid.blank?

      return resolve_for_current_user if @current_user.present?

      existing_identity = UserIdentity.includes(:user).find_by(provider:, uid:)
      return sign_in_result(existing_identity.user, existing_identity, linked: false) if refresh_identity!(existing_identity)

      existing_user = find_user_by_email
      if trusted_verified_email? && existing_user.present?
        link_result = LinkIdentity.call(
          user: existing_user,
          provider:,
          uid:,
          email:,
          email_verified: trusted_verified_email?,
          metadata: safe_metadata
        )
        return failure(link_result.error) unless link_result.success?

        confirm_user!(existing_user)
        return sign_in_result(existing_user, link_result.identity, linked: true)
      end

      return failure(:email_required) if email.blank?

      BeginSocialSignup.call(
        session: @session,
        provider:,
        uid:,
        email:,
        email_verified: trusted_verified_email?,
        name:
      )

      Result.new(
        outcome: :pending_signup,
        provider:,
        email:,
        name:,
        linked: false
      )
    end

    private

    def resolve_for_current_user
      link_result = LinkIdentity.call(
        user: @current_user,
        provider:,
        uid:,
        email:,
        email_verified: trusted_verified_email?,
        metadata: safe_metadata
      )
      return failure(link_result.error) unless link_result.success?

      confirm_user!(@current_user) if trusted_verified_email?

      Result.new(
        outcome: :linked_account,
        user: @current_user,
        identity: link_result.identity,
        provider:,
        email:,
        name:,
        linked: true
      )
    end

    def refresh_identity!(identity)
      return false if identity.blank?

      identity.update!(
        email: email.presence || identity.email,
        email_verified: trusted_verified_email? || identity.email_verified,
        metadata: identity.metadata.merge(safe_metadata),
        last_authenticated_at: Time.current
      )
    end

    def sign_in_result(user, identity, linked:)
      Result.new(
        outcome: :sign_in,
        user:,
        identity:,
        provider:,
        email: user.email,
        name: user.name,
        linked:
      )
    end

    def confirm_user!(user)
      return if user.confirmed?

      user.skip_confirmation!
      user.save!(validate: false)
    end

    def find_user_by_email
      return if email.blank?

      User.find_by("LOWER(email) = ?", email.downcase)
    end

    def trusted_verified_email?
      return false if email.blank?
      return true if provider == "apple"

      ActiveModel::Type::Boolean.new.cast(auth_value(:info, :email_verified)) ||
        ActiveModel::Type::Boolean.new.cast(auth_value(:extra, :raw_info, :email_verified))
    end

    def safe_metadata
      { name: name }.compact
    end

    def provider
      @provider ||= @auth&.provider.to_s.presence
    end

    def uid
      @uid ||= @auth&.uid.to_s.presence
    end

    def email
      @email ||= auth_value(:info, :email).presence || auth_value(:extra, :raw_info, :email).presence
    end

    def name
      @name ||= auth_value(:info, :name).presence
    end

    def auth_value(*path)
      path.reduce(@auth) do |value, key|
        break if value.blank?

        if value.respond_to?(:[])
          value[key]
        elsif value.respond_to?(key)
          value.public_send(key)
        end
      end
    end

    def failure(error)
      Result.new(
        outcome: :failure,
        provider:,
        email:,
        name:,
        error:,
        linked: false
      )
    end
  end
end
