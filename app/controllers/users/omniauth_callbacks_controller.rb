# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      handle_callback
    end

    def apple
      handle_callback
    end

    private

    def handle_callback
      result = Auth::ResolveIdentityFromOmniauth.call(
        auth: request.env["omniauth.auth"],
        session: session,
        current_user: current_user
      )

      case result.outcome
      when :sign_in
        if result.user.mfa_required?
          Auth::PendingMfaSession.start(
            session: session,
            user: result.user,
            primary_method: result.provider,
            remember_me: false,
            return_to: stored_location_for(:user)
          )

          redirect_path = result.user.mfa_setup_required? ? new_user_mfa_totp_enrollment_path : user_mfa_challenge_path
          return redirect_to redirect_path
        end

        log_sign_in(result)
        log_identity_linked(result) if result.linked
        set_flash_message!(:notice, :success, kind: provider_name(result.provider))
        sign_in_and_redirect result.user, event: :authentication
      when :linked_account
        log_identity_linked(result)
        redirect_to(origin_path || edit_profile_path, notice: t("social_registrations.linked_account_notice", provider: provider_name(result.provider)))
      when :pending_signup
        log_signup_started(result)
        redirect_to new_user_social_registration_path
      else
        log_identity_conflict(result) if result.error == :identity_conflict
        redirect_to failure_redirect_path, alert: t("social_registrations.errors.#{result.error}")
      end
    end

    def failure_redirect_path
      current_user.present? ? (origin_path || edit_profile_path) : new_user_session_path
    end

    def provider_name(provider)
      case provider.to_s
      when "apple" then "Apple"
      else "Google"
      end
    end

    def origin_path
      origin = request.env.dig("omniauth.params", "origin").presence || request.env["omniauth.origin"].presence
      return if origin.blank?

      candidate = origin.to_s
      return if candidate.start_with?("//")
      return unless candidate.start_with?("/")

      candidate
    end

    def log_sign_in(result)
      AuditLogs::EventLogger.call(
        event_type: "auth.sso_sign_in",
        actor: result.user,
        space: result.user.space,
        subject: result.user,
        request: request,
        metadata: audit_context_metadata.merge(provider: result.provider)
      )
    end

    def log_identity_linked(result)
      AuditLogs::EventLogger.call(
        event_type: "auth.sso_identity_linked",
        actor: result.user,
        space: result.user.space,
        subject: result.user,
        auditable: result.identity,
        request: request,
        metadata: audit_context_metadata.merge(provider: result.provider)
      )
    end

    def log_signup_started(result)
      AuditLogs::EventLogger.call(
        event_type: "auth.sso_signup_started",
        subject: { email: result.email, name: result.name },
        request: request,
        metadata: audit_context_metadata.merge(provider: result.provider)
      )
    end

    def log_identity_conflict(result)
      AuditLogs::EventLogger.call(
        event_type: "auth.sso_identity_conflict",
        subject: { email: result.email, name: result.name },
        request: request,
        metadata: audit_context_metadata.merge(provider: result.provider)
      )
    end
  end
end
