# frozen_string_literal: true

module Profiles
  module Security
    class BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :set_user

      private

      def set_user
        @user = current_user
      end

      def load_security_overview
        @identities = @user.user_identities.order(:provider)
        @passkeys = @user.user_passkeys.order(created_at: :desc)
        @active_recovery_codes_count = @user.user_recovery_codes.active.count
      end
    end
  end
end
