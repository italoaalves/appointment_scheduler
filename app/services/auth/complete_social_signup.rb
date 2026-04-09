# frozen_string_literal: true

module Auth
  class CompleteSocialSignup
    Result = Struct.new(:success?, :user, :identity, :error, keyword_init: true)

    def self.call(session:, params:)
      new(session:, params:).call
    end

    def initialize(session:, params:)
      @session = session
      @params = params.to_h.symbolize_keys
    end

    def call
      pending_signup = BeginSocialSignup.fetch(session: @session)
      return Result.new(success?: false, user: build_user({}), error: :missing_pending_signup) if pending_signup.blank?

      user = build_user(pending_signup)
      identity = nil
      success = false

      User.transaction do
        unless user.save
          raise ActiveRecord::Rollback
        end

        link_result = LinkIdentity.call(
          user:,
          provider: pending_signup[:provider],
          uid: pending_signup[:uid],
          email: pending_signup[:email],
          email_verified: pending_signup[:email_verified],
          metadata: { name: user.name }.compact
        )
        unless link_result.success?
          user.errors.add(:base, I18n.t("social_registrations.errors.#{link_result.error}"))
          raise ActiveRecord::Rollback
        end

        identity = link_result.identity
        success = true
      end

      return Result.new(success?: false, user:, error: :validation_failed) unless success

      BeginSocialSignup.clear(session: @session)
      Result.new(success?: true, user:, identity:)
    end

    private

    def build_user(pending_signup)
      password = Devise.friendly_token(32)

      User.new(
        name: @params[:name].presence || pending_signup[:name],
        email: pending_signup[:email],
        phone_number: @params[:phone_number],
        password: password,
        password_confirmation: password,
        accept_terms_of_service: @params[:accept_terms_of_service],
        accept_privacy_policy: @params[:accept_privacy_policy]
      ).tap do |user|
        user.require_phone_number = true
        user.require_legal_acceptance = true
        user.skip_confirmation! if BeginSocialSignup.trusted_verified_email?(pending_signup)
      end
    end
  end
end
