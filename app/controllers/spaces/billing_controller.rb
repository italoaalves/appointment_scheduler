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
      @plans        = Billing::Plan.visible
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
      new_plan_slug = params[:plan_id]
      subscription  = current_tenant.subscription

      if upgrade?(subscription, new_plan_slug)
        new_plan     = Billing::Plan.find_by_slug!(new_plan_slug)
        result       = Billing::SubscriptionManager.upgrade(subscription: subscription, new_billing_plan_id: new_plan.id)
        success_key  = "billing.plan_changed"
      elsif downgrade?(subscription, new_plan_slug)
        new_plan     = Billing::Plan.find_by_slug!(new_plan_slug)
        result       = Billing::SubscriptionManager.downgrade(subscription: subscription, new_billing_plan_id: new_plan.id)
        success_key  = "billing.downgrade_scheduled"
      else
        redirect_to settings_billing_path, alert: I18n.t("billing.no_change") and return
      end

      if result[:success]
        redirect_to settings_billing_path, notice: I18n.t(success_key)
      else
        redirect_to settings_billing_path, alert: result[:error]
      end
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

    def upgrade?(subscription, new_plan_id)
      return false if subscription.nil?
      current  = subscription.plan
      new_plan = Billing::Plan.find_by_slug!(new_plan_id)
      new_plan.price_cents > current.price_cents
    rescue ActiveRecord::RecordNotFound
      false
    end

    def downgrade?(subscription, new_plan_id)
      return false if subscription.nil?
      current  = subscription.plan
      new_plan = Billing::Plan.find_by_slug!(new_plan_id)
      new_plan.price_cents < current.price_cents
    rescue ActiveRecord::RecordNotFound
      false
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
