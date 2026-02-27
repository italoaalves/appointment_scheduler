# frozen_string_literal: true

module Billing
  module RequireActiveSubscription
    extend ActiveSupport::Concern

    included do
      append_before_action :enforce_active_subscription
      helper_method :subscription_restricted?
    end

    private

    def enforce_active_subscription
      return unless subscription_restricted?
      return if billing_exempt_action?

      if request.get?
        flash.now[:billing_alert] = I18n.t("billing.restricted_mode.banner")
      else
        redirect_back(
          fallback_location: root_path,
          alert: I18n.t("billing.restricted_mode.write_blocked")
        )
      end
    end

    def subscription_restricted?
      sub = Current.subscription
      return false if sub.nil?
      sub.expired?
    end

    def billing_exempt_action?
      false
    end
  end
end
