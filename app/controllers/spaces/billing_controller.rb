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
      @current_plan = @subscription&.plan
      @payments     = current_tenant.payments.order(created_at: :desc).limit(10)
      @credit       = current_tenant.message_credit
    end

    def edit
      @subscription = current_tenant.subscription
      unless @subscription&.active?
        redirect_to checkout_settings_billing_path and return
      end
      @plans = Billing::Plan.visible
    end

    def update
      new_plan     = Billing::Plan.find(params[:billing_plan_id])
      subscription = current_tenant.subscription

      if plan_change_limit_reached?(subscription)
        redirect_to settings_billing_path, alert: I18n.t("billing.plan_change_limit_reached") and return
      end

      if upgrade?(subscription, new_plan)
        result      = Billing::SubscriptionManager.upgrade(subscription: subscription, new_billing_plan_id: new_plan.id)
        success_msg = plan_change_notice(:upgrade, subscription)
      elsif downgrade?(subscription, new_plan)
        result      = Billing::SubscriptionManager.downgrade(subscription: subscription, new_billing_plan_id: new_plan.id)
        success_msg = plan_change_notice(:downgrade, subscription)
      else
        redirect_to settings_billing_path, alert: I18n.t("billing.no_change") and return
      end

      if result[:success]
        redirect_to settings_billing_path, notice: success_msg
      else
        redirect_to settings_billing_path, alert: result[:error]
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to settings_billing_path, alert: I18n.t("billing.no_change")
    end

    def checkout
      @subscription = current_tenant.subscription
      @plans        = Billing::Plan.visible
      @current_plan = @subscription&.plan
    end

    def subscribe
      plan_id        = params[:plan_id]
      payment_method = params[:payment_method]
      plan           = Billing::Plan.find_by_slug!(plan_id)
      subscription   = current_tenant.subscription

      if plan.price_cents > 0
        cpf_cnpj = params[:cpf_cnpj].to_s.gsub(/\D/, "")

        if cpf_cnpj.blank?
          redirect_to checkout_settings_billing_path, alert: I18n.t("billing.checkout.cpf_cnpj_required") and return
        end

        unless cpf_cnpj.length.in?([ 11, 14 ])
          redirect_to checkout_settings_billing_path, alert: I18n.t("billing.checkout.cpf_cnpj_invalid") and return
        end

        current_user.update!(cpf_cnpj: cpf_cnpj)
      end

      asaas_customer_id = resolve_asaas_customer(subscription)

      result = Billing::SubscriptionManager.subscribe(
        space:             current_tenant,
        billing_plan_id:   plan.id,
        payment_method:    payment_method&.to_sym,
        asaas_customer_id: asaas_customer_id
      )

      if result[:success]
        redirect_to settings_billing_path, notice: I18n.t("billing.checkout.success")
      else
        redirect_to checkout_settings_billing_path, alert: result[:error]
      end
    rescue Billing::AsaasClient::ApiError => e
      redirect_to checkout_settings_billing_path, alert: e.message
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
      redirect_to checkout_settings_billing_path
    end

    private

    # Returns true once 2 plan changes have already been logged in the current period.
    # Guards against abuse of the plan-change window.
    def plan_change_limit_reached?(subscription)
      return false unless subscription&.current_period_start

      subscription.billing_events
                  .where(event_type: %w[plan.changed plan.downgrade_scheduled])
                  .where(created_at: subscription.current_period_start..)
                  .count >= 2
    end

    # Builds the success flash message, appending a manual-payment reminder
    # for PIX and Boleto subscriptions so customers know to act.
    def plan_change_notice(type, subscription)
      base   = I18n.t("billing.#{type == :upgrade ? 'plan_changed' : 'downgrade_scheduled'}")
      method = subscription&.payment_method&.to_sym
      return base unless method.in?(%i[pix boleto])

      "#{base} #{I18n.t("billing.payment_method_action_required.#{method}")}"
    end

    def upgrade?(subscription, new_plan)
      current_plan = subscription&.billing_plan
      return false unless current_plan
      new_plan.price_cents > current_plan.price_cents
    end

    def downgrade?(subscription, new_plan)
      current_plan = subscription&.billing_plan
      return false unless current_plan
      new_plan.price_cents < current_plan.price_cents
    end

    def resolve_asaas_customer(subscription)
      return subscription.asaas_customer_id if subscription&.asaas_customer_id.present?

      plan = Billing::Plan.find_by_slug!(params[:plan_id])
      return nil if plan.price_cents == 0

      owner = current_tenant.users.find_by(id: current_tenant.owner_id) || current_user
      result = Billing::AsaasClient.new.create_customer(
        name:               owner.name,
        email:              owner.email,
        cpf_cnpj:           owner.cpf_cnpj.to_s,
        external_reference: "space_#{current_tenant.id}"
      )
      customer_id = result["id"]
      subscription&.update_column(:asaas_customer_id, customer_id)
      customer_id
    end
  end
end
