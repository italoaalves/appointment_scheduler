# frozen_string_literal: true

module Onboarding
  class WizardController < ApplicationController
    layout "onboarding"
    before_action :authenticate_user!
    before_action :ensure_space_owner!
    before_action :ensure_not_complete!

    def show
      @step = [ current_tenant.onboarding_step + 1, 3 ].min
      render "onboarding/step#{@step}"
    end

    private

    def ensure_space_owner!
      return if current_user.space_owner?

      redirect_to root_path, alert: t("onboarding.owner_only")
    end

    def ensure_not_complete!
      return unless current_tenant.onboarding_complete?

      redirect_to root_path
    end
  end
end
