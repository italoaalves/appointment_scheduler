# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    skip_before_action :allow_params_authentication!, only: :create

    def create
      result = Auth::PrimaryAuthentication.call(
        email: sign_in_params[:email],
        password: sign_in_params[:password]
      )

      unless result.success?
        self.resource = resource_class.new(email: sign_in_params[:email])
        clean_up_passwords(resource)
        flash.now[:alert] = failure_message_for(result.error)
        return render :new, status: Devise.responder.error_status
      end

      user = result.user
      remember_me_requested = ActiveModel::Type::Boolean.new.cast(sign_in_params[:remember_me])

      if user.mfa_required?
        Auth::PendingMfaSession.start(
          session: session,
          user: user,
          primary_method: :password,
          remember_me: remember_me_requested,
          return_to: stored_location_for(resource_name)
        )

        redirect_path = user.mfa_setup_required? ? new_user_mfa_totp_enrollment_path : user_mfa_challenge_path
        return redirect_to redirect_path, status: Devise.responder.redirect_status
      end

      complete_sign_in(user, remember_me_requested:)
    end

    def destroy
      Auth::PendingMfaSession.clear(session:)
      Auth::PendingMfaSession.clear_verified(session:)
      super
    end

    private

    def complete_sign_in(user, remember_me_requested:)
      Auth::PendingMfaSession.clear(session:)
      Auth::PendingMfaSession.clear_verified(session:)
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, user)
      remember_me(user) if remember_me_requested
      respond_with user, location: after_sign_in_path_for(user)
    end

    def failure_message_for(error)
      I18n.t("devise.failure.#{error}", authentication_keys: User.human_attribute_name(:email))
    rescue I18n::MissingTranslationData
      I18n.t("devise.failure.invalid", authentication_keys: User.human_attribute_name(:email))
    end
  end
end
