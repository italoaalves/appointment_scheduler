# frozen_string_literal: true

require "zlib"

module Billing
  class CreditManager
    def self.purchase(space:, amount:, actor: nil)
      new(space).purchase(amount: amount, actor: actor)
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
