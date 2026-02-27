# frozen_string_literal: true

module Platform
  class BillingController < Platform::BaseController
    def index
      @total_active   = Billing::Subscription.where(status: :active).count
      @total_trialing = Billing::Subscription.where(status: :trialing).count
      @total_expired  = Billing::Subscription.where(status: :expired).count
      @total_canceled = Billing::Subscription.where(status: :canceled).count

      @mrr_cents = Billing::Subscription.where(status: :active).sum do |sub|
        sub.plan.price_cents
      end

      @recent_events  = Billing::BillingEvent
                          .order(created_at: :desc)
                          .limit(50)
                          .includes(:space, :subscription)
      @subscriptions  = Billing::Subscription
                          .includes(:space)
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(20)
    end
  end
end
