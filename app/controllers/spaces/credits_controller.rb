# frozen_string_literal: true

module Spaces
  class CreditsController < Spaces::BaseController
    include RequirePermission

    require_permission :manage_space, redirect_to: :root_path

    def show
      @credit            = current_tenant.message_credit
      @subscription      = current_tenant.subscription
      @bundles           = Billing::CreditBundle.available
      @pending_purchases = current_tenant.credit_purchases.pending.order(created_at: :desc)
      @events            = Billing::BillingEvent
                             .where(space_id: current_tenant.id)
                             .where("event_type LIKE 'credits.%'")
                             .order(created_at: :desc)
                             .limit(20)
    end

    def checkout
      @bundle       = Billing::CreditBundle.available.find(params[:bundle_id])
      @subscription = current_tenant.subscription
    end

    def create
      bundle         = Billing::CreditBundle.available.find(params[:bundle_id])
      payment_method = sanitize_payment_method(params[:payment_method])

      result = Billing::CreditManager.initiate_purchase(
        space:          current_tenant,
        bundle:         bundle,
        payment_method: payment_method,
        actor:          current_user
      )

      if result[:success]
        redirect_to payment_settings_credits_path(purchase_id: result[:credit_purchase].id),
                    status: :see_other
      else
        redirect_to settings_credits_path, alert: result[:error]
      end
    end

    def payment
      @purchase    = current_tenant.credit_purchases.find(params[:purchase_id])
      @pix_qr_code = @purchase.pix_qr_code_base64
      @pix_payload  = @purchase.pix_payload
      @invoice_url  = @purchase.invoice_url
    end

    private

    def sanitize_payment_method(param)
      return :pix if param.blank?
      sym = param.to_sym
      %i[pix credit_card boleto].include?(sym) ? sym : :pix
    end

    public

    def status
      purchase = current_tenant.credit_purchases.find(params[:purchase_id])
      render json: { status: purchase.status }
    end
  end
end
