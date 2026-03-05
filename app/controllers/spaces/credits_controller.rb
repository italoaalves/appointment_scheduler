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

    def create
      amount = params[:amount].to_i

      result = Billing::CreditManager.initiate_purchase(
        space:  current_tenant,
        amount: amount,
        actor:  current_user
      )

      if result[:success]
        purchase = result[:credit_purchase]
        if purchase.pix_qr_code_base64.present?
          redirect_to payment_settings_credits_path(purchase_id: purchase.id),
                      status: :see_other
        else
          redirect_to settings_credits_path,
                      notice: I18n.t("billing.credits.purchase_initiated")
        end
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
  end
end
