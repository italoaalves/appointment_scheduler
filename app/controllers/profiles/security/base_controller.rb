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
    end
  end
end
