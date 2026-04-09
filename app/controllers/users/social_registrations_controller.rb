# frozen_string_literal: true

module Users
  class SocialRegistrationsController < ApplicationController
    before_action :set_pending_signup

    def new
      @user = build_user
    end

    def create
      result = Auth::CompleteSocialSignup.call(session: session, params: social_registration_params)

      if result.success?
        log_signup_completed(result)
        sign_in(:user, result.user)
        redirect_to after_sign_in_path_for(result.user), notice: t("social_registrations.create.notice", provider: provider_name)
      else
        @user = result.user
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_pending_signup
      @pending_signup = Auth::BeginSocialSignup.fetch(session: session)
      return if @pending_signup.present?

      redirect_to new_user_registration_path, alert: t("social_registrations.session_expired")
    end

    def social_registration_params
      params.require(:user).permit(
        :name,
        :phone_number,
        :accept_terms_of_service,
        :accept_privacy_policy
      )
    end

    def build_user
      User.new(
        name: @pending_signup[:name],
        email: @pending_signup[:email]
      ).tap do |user|
        user.require_phone_number = true
        user.require_legal_acceptance = true
      end
    end

    def provider_name
      @provider_name ||= @pending_signup[:provider] == "apple" ? "Apple" : "Google"
    end
    helper_method :provider_name

    def log_signup_completed(result)
      AuditLogs::EventLogger.call(
        event_type: "auth.sso_signup_completed",
        actor: result.user,
        space: result.user.space,
        subject: result.user,
        auditable: result.identity,
        request: request,
        metadata: audit_context_metadata.merge(provider: result.identity.provider)
      )
    end
  end
end
