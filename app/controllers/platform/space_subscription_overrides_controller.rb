# frozen_string_literal: true

module Platform
  class SpaceSubscriptionOverridesController < Platform::BaseController
    before_action :set_space

    def edit
      @subscription = @space.subscription
      @credit       = @space.message_credit
      @plans        = Billing::Plan.visible
    end

    def update
      case params[:override_action]
      when "extend_trial"            then extend_trial
      when "change_plan"             then change_plan
      when "grant_credits"           then grant_credits
      when "reactivate_subscription" then reactivate_subscription
      else
        redirect_to platform_space_path(@space), alert: "Unknown action."
      end
    end

    private

    def set_space
      @space = Space.find(params[:space_id])
    end

    def extend_trial
      subscription = @space.subscription
      days = params[:days].to_i

      unless days > 0
        redirect_to edit_platform_space_subscription_override_path(@space), alert: "Invalid days."
        return
      end

      subscription.update!(
        trial_ends_at: subscription.trial_ends_at + days.days,
        status: :trialing
      )

      Billing::BillingEvent.create!(
        space:        @space,
        subscription: subscription,
        event_type:   "manual_override",
        metadata:     { action: "extend_trial", days: days },
        actor_id:     current_user.id
      )

      redirect_to platform_space_path(@space), notice: "Trial extended by #{days} days."
    end

    def change_plan
      new_plan_id   = params[:plan_id]
      subscription  = @space.subscription
      old_plan_slug = subscription.billing_plan.slug
      new_plan      = Billing::Plan.find_by_slug!(new_plan_id)

      subscription.update!(billing_plan: new_plan)

      Billing::BillingEvent.create!(
        space:        @space,
        subscription: subscription,
        event_type:   "manual_override",
        metadata:     { action: "change_plan", from: old_plan_slug, to: new_plan_id },
        actor_id:     current_user.id
      )

      redirect_to platform_space_path(@space), notice: "Plan changed to #{new_plan_id}."
    end

    def grant_credits
      amount = params[:amount].to_i

      unless amount > 0
        redirect_to edit_platform_space_subscription_override_path(@space), alert: "Invalid amount."
        return
      end

      ActiveRecord::Base.transaction do
        credit = Billing::MessageCredit.find_or_create_by!(space: @space) do |c|
          c.balance = 0
          c.monthly_quota_remaining = 0
          c.quota_refreshed_at = Time.current
        end
        credit.increment!(:balance, amount)

        Billing::BillingEvent.create!(
          space:      @space,
          event_type: "credits.granted",
          metadata:   { amount: amount },
          actor_id:   current_user.id
        )
      end

      redirect_to platform_space_path(@space), notice: "#{amount} credits granted."
    end

    def reactivate_subscription
      subscription = @space.subscription

      unless subscription
        redirect_to edit_platform_space_subscription_override_path(@space), alert: "No subscription to reactivate."
        return
      end

      asaas_subscription_id = params[:asaas_subscription_id].to_s.strip
      reason = params[:reason].to_s.strip

      if asaas_subscription_id.blank?
        redirect_to edit_platform_space_subscription_override_path(@space), alert: "Asaas subscription ID is required."
        return
      end

      if reason.blank?
        redirect_to edit_platform_space_subscription_override_path(@space), alert: "A reason is required for audit purposes."
        return
      end

      old_status = subscription.status

      ActiveRecord::Base.transaction do
        subscription.update!(
          status:                :active,
          asaas_subscription_id: asaas_subscription_id,
          canceled_at:           nil,
          current_period_start:  Time.current,
          current_period_end:    1.month.from_now
        )

        Billing::BillingEvent.create!(
          space:        @space,
          subscription: subscription,
          event_type:   "manual_override",
          metadata:     {
            action:                "reactivate_subscription",
            previous_status:       old_status,
            asaas_subscription_id: asaas_subscription_id,
            reason:                reason
          },
          actor_id:     current_user.id
        )
      end

      redirect_to platform_space_path(@space), notice: "Subscription reactivated successfully."
    end
  end
end
