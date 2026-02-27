# frozen_string_literal: true

module Billing
  class WebhookProcessor
    BILLING_TYPE_MAP = {
      "PIX"         => :pix,
      "CREDIT_CARD" => :credit_card,
      "BOLETO"      => :boleto
    }.freeze

    def self.call(payload_json)
      new(payload_json).call
    end

    def initialize(payload_json)
      @payload = payload_json.is_a?(String) ? JSON.parse(payload_json) : payload_json
    rescue JSON::ParserError => e
      Rails.logger.error("[Billing::WebhookProcessor] Invalid JSON payload: #{e.message}")
      @payload = {}
    end

    def call
      event_name = @payload["event"].to_s
      return log_unknown_event(event_name) if event_name.blank?

      case event_name
      when "PAYMENT_CONFIRMED", "PAYMENT_RECEIVED" then handle_payment_confirmed
      when "PAYMENT_OVERDUE"                        then handle_payment_overdue
      when "PAYMENT_CREATED"                        then handle_payment_created
      when "PAYMENT_DELETED"                        then handle_payment_deleted
      when "PAYMENT_REFUNDED"                       then handle_payment_refunded
      when "SUBSCRIPTION_DELETED"                   then handle_subscription_deleted
      else log_unknown_event(event_name)
      end
    rescue => e
      Rails.logger.error("[Billing::WebhookProcessor] Unhandled error for event=#{@payload['event']}: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
    end

    private

    # ── Handlers ──────────────────────────────────────────────────────────────

    def handle_payment_confirmed
      payment_data = @payload["payment"] || {}
      asaas_payment_id = payment_data["id"]
      return log_missing("asaas_payment_id", "PAYMENT_CONFIRMED") if asaas_payment_id.blank?

      return if already_processed?("webhook.payment_confirmed", asaas_payment_id)

      subscription = find_subscription_for_payment(payment_data)
      return log_missing_subscription(asaas_payment_id) unless subscription

      ActiveRecord::Base.transaction do
        payment = find_or_create_payment(payment_data, subscription)
        payment.update!(status: :confirmed, paid_at: parse_date(payment_data["confirmedDate"]) || Time.current)

        if subscription.trialing? || subscription.past_due?
          subscription.update!(status: :active)
        end

        log_webhook_event("webhook.payment_confirmed", subscription, asaas_payment_id: asaas_payment_id)
      end
    end

    def handle_payment_overdue
      payment_data     = @payload["payment"] || {}
      asaas_payment_id = payment_data["id"]
      return log_missing("asaas_payment_id", "PAYMENT_OVERDUE") if asaas_payment_id.blank?

      return if already_processed?("webhook.payment_overdue", asaas_payment_id)

      subscription = find_subscription_for_payment(payment_data)
      return log_missing_subscription(asaas_payment_id) unless subscription

      ActiveRecord::Base.transaction do
        payment = find_or_create_payment(payment_data, subscription)
        payment.update!(status: :overdue)
        subscription.update!(status: :past_due)

        log_webhook_event("webhook.payment_overdue", subscription, asaas_payment_id: asaas_payment_id)
      end
    end

    def handle_payment_created
      payment_data     = @payload["payment"] || {}
      asaas_payment_id = payment_data["id"]
      return log_missing("asaas_payment_id", "PAYMENT_CREATED") if asaas_payment_id.blank?

      return if Billing::Payment.exists?(asaas_payment_id: asaas_payment_id)

      subscription = find_subscription_for_payment(payment_data)
      return log_missing_subscription(asaas_payment_id) unless subscription

      ActiveRecord::Base.transaction do
        find_or_create_payment(payment_data, subscription)
        log_webhook_event("webhook.payment_created", subscription, asaas_payment_id: asaas_payment_id)
      end
    end

    def handle_payment_deleted
      payment_data     = @payload["payment"] || {}
      asaas_payment_id = payment_data["id"]
      return if asaas_payment_id.blank?

      payment = Billing::Payment.find_by(asaas_payment_id: asaas_payment_id)
      return unless payment

      payment.update!(status: :failed)
    end

    def handle_payment_refunded
      payment_data     = @payload["payment"] || {}
      asaas_payment_id = payment_data["id"]
      return log_missing("asaas_payment_id", "PAYMENT_REFUNDED") if asaas_payment_id.blank?

      return if already_processed?("webhook.payment_refunded", asaas_payment_id)

      payment = Billing::Payment.find_by(asaas_payment_id: asaas_payment_id)
      return unless payment

      ActiveRecord::Base.transaction do
        payment.update!(status: :refunded)
        log_webhook_event("webhook.payment_refunded", payment.subscription, asaas_payment_id: asaas_payment_id)
      end
    end

    def handle_subscription_deleted
      subscription_data     = @payload["subscription"] || @payload["payment"] || {}
      asaas_subscription_id = subscription_data["id"] || @payload.dig("payment", "subscription")
      return log_missing("asaas_subscription_id", "SUBSCRIPTION_DELETED") if asaas_subscription_id.blank?

      return if already_processed?("webhook.subscription_deleted", asaas_subscription_id,
                                   key: "asaas_subscription_id")

      subscription = Billing::Subscription.includes(:billing_plan)
                                         .find_by(asaas_subscription_id: asaas_subscription_id)
      return log_missing_subscription(asaas_subscription_id) unless subscription

      ActiveRecord::Base.transaction do
        subscription.update!(status: :canceled, canceled_at: Time.current)
        log_webhook_event("webhook.subscription_deleted", subscription,
                          asaas_subscription_id: asaas_subscription_id)
      end
    end

    # ── Lookup helpers ────────────────────────────────────────────────────────

    def find_subscription_for_payment(payment_data)
      asaas_sub_id = payment_data["subscription"]
      if asaas_sub_id.present?
        sub = Billing::Subscription.includes(:billing_plan)
                                   .find_by(asaas_subscription_id: asaas_sub_id)
        return sub if sub
      end

      external_ref = payment_data["externalReference"].to_s
      space_id     = external_ref.sub("space_", "").to_i
      Billing::Subscription.includes(:billing_plan).find_by(space_id: space_id) if space_id.positive?
    end

    def find_or_create_payment(payment_data, subscription)
      asaas_payment_id = payment_data["id"]
      billing_type     = BILLING_TYPE_MAP[payment_data["billingType"]] || :pix
      amount_cents     = ((payment_data["value"].to_f) * 100).round

      Billing::Payment.find_or_create_by!(asaas_payment_id: asaas_payment_id) do |p|
        p.subscription   = subscription
        p.space_id       = subscription.space_id
        p.amount_cents   = amount_cents.positive? ? amount_cents : 1
        p.payment_method = billing_type
        p.status         = :pending
      end
    end

    # ── Idempotency ───────────────────────────────────────────────────────────

    def already_processed?(event_type, id_value, key: "asaas_payment_id")
      Billing::BillingEvent.where(event_type: event_type)
                           .where("metadata->>? = ?", key, id_value)
                           .exists?
    end

    def log_webhook_event(event_type, subscription, metadata = {})
      Billing::BillingEvent.create!(
        space_id:        subscription.space_id,
        subscription_id: subscription.id,
        event_type:      event_type,
        metadata:        metadata.merge(plan_slug: subscription.plan.slug)
      )
    end

    # ── Logging helpers ───────────────────────────────────────────────────────

    def log_unknown_event(event_name)
      Rails.logger.info("[Billing::WebhookProcessor] Unknown event type: #{event_name.inspect} — ignoring")
    end

    def log_missing(field, event)
      Rails.logger.warn("[Billing::WebhookProcessor] #{event} missing #{field} — skipping")
    end

    def log_missing_subscription(id)
      Rails.logger.warn("[Billing::WebhookProcessor] No subscription found for id=#{id} — skipping")
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s).in_time_zone rescue nil
    end
  end
end
