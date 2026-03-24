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
    def self.initiate_purchase(space:, bundle:, payment_method:, actor: nil, asaas_client: Billing::AsaasClient.new)
      new(space).initiate_purchase(bundle: bundle, payment_method: payment_method,
                                   actor: actor, asaas_client: asaas_client)
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
    def initiate_purchase(bundle:, payment_method:, actor: nil, asaas_client: Billing::AsaasClient.new)
      subscription = @space.subscription

      if Billing::CreditPurchase.where(space: @space, status: :pending).count >= 3
        return { success: false, error: I18n.t("billing.credits.too_many_pending") }
      end

      unless subscription&.asaas_customer_id.present?
        return { success: false, error: I18n.t("billing.credits.no_subscription") }
      end

      credit_purchase = Billing::CreditPurchase.create!(
        space:         @space,
        credit_bundle: bundle,
        amount:        bundle.amount,
        price_cents:   bundle.price_cents,
        actor_id:      actor&.id,
        status:        :pending
      )

      result = asaas_client.create_payment(
        customer_id:        subscription.asaas_customer_id,
        billing_type:       payment_method,
        value:              bundle.price_cents / 100.0,
        due_date:           boleto_due_date_for_method(payment_method),
        description:        "#{bundle.amount} WhatsApp credits",
        external_reference: "credit_purchase_#{credit_purchase.id}"
      )

      bank_slip_url = result["bankSlipUrl"] if payment_method == :boleto
      pix_data      = asaas_client.pix_qr_code(result["id"]) if payment_method == :pix

      credit_purchase.update!(
        asaas_payment_id:   result["id"],
        invoice_url:        result["invoiceUrl"],
        bank_slip_url:      bank_slip_url,
        pix_qr_code_base64: pix_data&.dig("encodedImage"),
        pix_payload:        pix_data&.dig("payload")
      )

      { success: true, credit_purchase: credit_purchase }
    rescue Billing::AsaasClient::ApiError => e
      credit_purchase&.update_column(:status, :failed)
      Rails.logger.error("[Billing::CreditManager] Asaas API error during initiate_purchase: #{e.message}")
      { success: false, error: I18n.t("billing.generic_error") }
    end

    # Grants credits after payment is confirmed. Idempotent — safe to call twice.
    # Errors are intentionally NOT rescued: they propagate to ProcessWebhookJob
    # so Solid Queue can retry automatically.
    def fulfill_purchase(credit_purchase:)
      # Fast path: avoid the lock entirely when clearly already done.
      return { success: true } if credit_purchase.completed?

      ActiveRecord::Base.transaction do
        lock_key = Zlib.crc32("credit_fulfill:#{@space.id}")
        ActiveRecord::Base.connection.exec_query(
          "SELECT pg_advisory_xact_lock($1)", "AdvisoryLock", [ lock_key ]
        )

        # Re-check after acquiring the lock — another concurrent fulfillment may
        # have completed the purchase while this thread was waiting.
        credit_purchase.reload
        return { success: true } if credit_purchase.completed?

        purchase(amount: credit_purchase.amount)
        credit_purchase.update!(status: :completed)

        Billing::BillingEvent.create!(
          space_id:   @space.id,
          event_type: "credits.fulfilled",
          metadata:   {
            credit_purchase_id: credit_purchase.id,
            asaas_payment_id:   credit_purchase.asaas_payment_id,
            amount:             credit_purchase.amount
          }
        )
      end

      Billing::CreditPurchaseFulfilledNotificationJob.perform_later(credit_purchase.id)

      { success: true }
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

    def boleto_due_date_for_method(payment_method)
      return Date.current.to_s unless payment_method == :boleto

      date = Date.current
      added = 0
      loop do
        date += 1
        added += 1 unless date.saturday? || date.sunday?
        break if added >= 3
      end
      date.to_s
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
