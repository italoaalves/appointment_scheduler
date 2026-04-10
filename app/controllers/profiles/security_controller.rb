# frozen_string_literal: true

module Profiles
  class SecurityController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
      @identities = @user.user_identities.order(:provider)
      @passkeys = @user.user_passkeys.order(created_at: :desc)
      @active_recovery_codes_count = @user.user_recovery_codes.active.count
    end
  end
end
