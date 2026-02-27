# frozen_string_literal: true

module Spaces
  class CreditsController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_space, redirect_to: :root_path

    def show
      @credit       = current_tenant.message_credit
      @subscription = current_tenant.subscription
      @bundles      = Billing::CreditBundle.bundles
      @events       = Billing::BillingEvent
                        .where(space_id: current_tenant.id)
                        .where("event_type LIKE 'credits.%'")
                        .order(created_at: :desc)
                        .limit(20)
    end

    def create
      amount = params[:amount].to_i
      valid_amounts = Billing::CreditBundle.bundles.map(&:amount)
      unless valid_amounts.include?(amount)
        redirect_to settings_credits_path, alert: I18n.t("billing.credits.invalid_amount") and return
      end

      result = Billing::CreditManager.purchase(
        space: current_tenant,
        amount: amount,
        actor: current_user
      )

      if result[:success]
        redirect_to settings_credits_path, notice: I18n.t("billing.credits.purchased", amount: amount)
      else
        redirect_to settings_credits_path, alert: result[:error]
      end
    end
  end
end
