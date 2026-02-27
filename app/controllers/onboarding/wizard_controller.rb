# frozen_string_literal: true

module Onboarding
  class WizardController < ApplicationController
    layout "onboarding"
    before_action :authenticate_user!
    before_action :ensure_space_owner!
    before_action :ensure_not_complete!, only: [ :show ]

    def show
      @step = [ current_tenant.onboarding_step + 1, 3 ].min
      render "onboarding/step#{@step}"
    end

    def update_step1
      current_tenant.update!(onboarding_step: 1)
      redirect_to onboarding_wizard_path
    end

    def update_step2
      current_tenant.update!(onboarding_step: 2)
      redirect_to onboarding_wizard_path
    end

    def update_step3
      current_tenant.update!(onboarding_step: 3, completed_onboarding_at: Time.current)
      redirect_to root_path, notice: t("onboarding.step3.completed_notice")
    end

    def skip
      current_tenant.update!(completed_onboarding_at: Time.current)
      redirect_to root_path
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
