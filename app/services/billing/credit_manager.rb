# frozen_string_literal: true

require "zlib"

module Billing
  class CreditManager
    # Direct credit grant — used by webhook fulfillment and platform admin overrides.
    # Controllers must NOT call this directly; use initiate_purchase instead.
    def self.purchase(space:, amount:, actor: nil)
      new(space).purchase(amount: amount, actor: actor)
    end

    # Creates an Asaas charge and a pending CreditPurchase. Credits are NOT
    # granted here; they are granted when the webhook confirms payment.
    def self.initiate_purchase(space:, amount:, actor: nil, asaas_client: Billing::AsaasClient.new)
      new(space).initiate_purchase(amount: amount, actor: actor, asaas_client: asaas_client)
    end

    # Grants credits after Asaas confirms the payment for a CreditPurchase.
    def self.fulfill_purchase(space:, credit_purchase:)
      new(space).fulfill_purchase(credit_purchase: credit_purchase)
    end

    def self.deduct(space:)
      new(space).deduct
    end

    def self.refund(space:, source:)
      new(space).refund(source: source)
    end

    def self.sufficient?(space:)
      new(space).sufficient?
    end

    def initialize(space)
      @space = space
    end

    # Direct credit grant used only by webhooks and admin overrides.
    def purchase(amount:, actor: nil)
      ActiveRecord::Base.transaction do
        Billing::CreditBundle.available.find_by!(amount: amount)

        credit = Billing::MessageCredit.find_or_initialize_by(space_id: @space.id)
        credit.balance ||= 0
        credit.monthly_quota_remaining ||= 0
        credit.balance += amount
        credit.save!

        Billing::BillingEvent.create!(
          space_id:        @space.id,
          event_type:      "credits.purchased",
          metadata:        { amount: amount },
          actor_id:        actor&.id
        )

        { success: true, new_balance: credit.balance }
      end
    end

    # Creates a pending Asaas charge and a CreditPurchase record.
    # Credits are NOT granted — the webhook calls fulfill_purchase after payment.
    def initiate_purchase(amount:, actor: nil, asaas_client: Billing::AsaasClient.new)
      bundle       = Billing::CreditBundle.available.find_by!(amount: amount)
      subscription = @space.subscription

      unless subscription&.asaas_customer_id.present?
        return { success: false, error: I18n.t("billing.credits.no_subscription") }
      end

      credit_purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: bundle,
        amount:        amount,
        price_cents:   bundle.price_cents,
        actor_id:      actor&.id,
        status:        :pending
      )

      result = asaas_client.create_payment(
        customer_id:        subscription.asaas_customer_id,
        billing_type:       subscription.payment_method.to_sym,
        value:              bundle.price_cents / 100.0,
        due_date:           Date.current.to_s,
        description:        "#{amount} WhatsApp credits",
        external_reference: "credit_purchase_#{credit_purchase.id}"
      )

      credit_purchase.update!(
        asaas_payment_id: result["id"],
        invoice_url:      result["invoiceUrl"]
      )

      { success: true, credit_purchase: credit_purchase, invoice_url: result["invoiceUrl"] }
    rescue Billing::AsaasClient::ApiError => e
      credit_purchase&.update_column(:status, :failed)
      { success: false, error: e.message }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: I18n.t("billing.credits.invalid_amount") }
    end

    # Grants credits after payment is confirmed. Idempotent — safe to call twice.
    def fulfill_purchase(credit_purchase:)
      return { success: true } if credit_purchase.completed?

      purchase(amount: credit_purchase.amount)
      credit_purchase.update!(status: :completed)

      { success: true }
    rescue => e
      Rails.logger.error("[CreditManager] fulfill_purchase failed for #{credit_purchase.id}: #{e.message}")
      { success: false, error: e.message }
    end

    def deduct
      plan = @space.subscription&.plan
      return { success: true, source: :unlimited } if plan&.whatsapp_unlimited?

      ActiveRecord::Base.transaction do
        lock_key = Zlib.crc32("message_credits:#{@space.id}")
        ActiveRecord::Base.connection.exec_query(
          "SELECT pg_advisory_xact_lock($1)", "AdvisoryLock", [ lock_key ]
        )

        credit = Billing::MessageCredit.find_by(space_id: @space.id)
        return { success: false, reason: :insufficient_credits } if credit.nil?

        if credit.monthly_quota_remaining > 0
          credit.decrement!(:monthly_quota_remaining)
          { success: true, source: :quota }
        elsif credit.balance > 0
          credit.decrement!(:balance)
          { success: true, source: :purchased }
        else
          { success: false, reason: :insufficient_credits }
        end
      end
    end

    def refund(source:)
      return { success: true } if source == :unlimited

      ActiveRecord::Base.transaction do
        credit = Billing::MessageCredit.find_by(space_id: @space.id)
        return { success: true } if credit.nil?

        case source
        when :quota
          credit.increment!(:monthly_quota_remaining)
        when :purchased
          credit.increment!(:balance)
        end

        { success: true }
      end
    end

    def sufficient?
      plan = @space.subscription&.plan
      return true if plan&.whatsapp_unlimited?

      credit = Billing::MessageCredit.find_by(space_id: @space.id)
      return false if credit.nil?

      credit.balance > 0 || credit.monthly_quota_remaining > 0
    end
  end
end
