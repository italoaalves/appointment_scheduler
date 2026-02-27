# frozen_string_literal: true

module Spaces
  class BillingController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_space, redirect_to: :root_path

    def billing_exempt_action?
      true
    end

    def show
      @subscription = current_tenant.subscription
      @plans        = Billing::Plan.all
      @current_plan = @subscription&.plan
      @payments     = current_tenant.payments.order(created_at: :desc).limit(10)
      @credit       = current_tenant.message_credit
    end

    def edit
      @subscription = current_tenant.subscription
      @plans        = Billing::Plan.all
    end

    def update
      new_plan_id  = params[:plan_id]
      subscription = current_tenant.subscription

      if upgrade?(subscription, new_plan_id)
        result = Billing::SubscriptionManager.upgrade(subscription: subscription, new_plan_id: new_plan_id)
      elsif downgrade?(subscription, new_plan_id)
        result = Billing::SubscriptionManager.downgrade(subscription: subscription, new_plan_id: new_plan_id)
      else
        redirect_to settings_billing_path, alert: I18n.t("billing.no_change") and return
      end

      if result[:success]
        redirect_to settings_billing_path, notice: I18n.t("billing.plan_changed")
      else
        redirect_to settings_billing_path, alert: result[:error]
      end
    end

    def cancel
      result = Billing::SubscriptionManager.cancel(subscription: current_tenant.subscription)
      if result[:success]
        redirect_to settings_billing_path, notice: I18n.t("billing.canceled")
      else
        redirect_to settings_billing_path, alert: result[:error]
      end
    end

    def resubscribe
      redirect_to settings_billing_path, alert: I18n.t("billing.resubscribe_unavailable")
    end

    private

    def upgrade?(subscription, new_plan_id)
      subscription&.plan_id == "starter" && new_plan_id == "pro"
    end

    def downgrade?(subscription, new_plan_id)
      subscription&.plan_id == "pro" && new_plan_id == "starter"
    end
  end
end
