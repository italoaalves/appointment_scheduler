# frozen_string_literal: true

namespace :dev do
  desc "List all spaces with their plan, subscription status, and credit balance"
  task spaces: :environment do
    abort_unless_dev!

    Space.includes(subscription: :billing_plan, message_credit: nil).find_each do |space|
      sub   = space.subscription
      plan  = sub&.billing_plan
      cred  = space.message_credit

      puts format(
        "%-4d %-25s %-12s %-10s credits: %s (monthly: %s)  owner: %s",
        space.id,
        space.name.truncate(25),
        plan&.slug || "no plan",
        sub&.status || "none",
        cred&.balance || 0,
        cred&.monthly_quota_remaining || 0,
        space.owner&.email || "—"
      )
    end
  end

  desc "Change a space's plan. Usage: rake dev:set_plan SPACE_ID=1 PLAN=pro"
  task set_plan: :environment do
    abort_unless_dev!
    space = Space.find(ENV.fetch("SPACE_ID"))
    plan  = Billing::Plan.find_by_slug!(ENV.fetch("PLAN"))
    sub   = space.subscription || space.build_subscription

    sub.update!(
      billing_plan: plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 30.days.from_now,
      trial_ends_at: nil
    )

    # Ensure message credit exists with plan quota
    credit = space.message_credit || space.create_message_credit!(balance: 0, monthly_quota_remaining: 0)
    credit.update!(monthly_quota_remaining: plan.whatsapp_monthly_quota.to_i)

    puts "#{space.name} → #{plan.name} (active), monthly quota: #{credit.monthly_quota_remaining}"
  end

  desc "Set subscription status. Usage: rake dev:set_status SPACE_ID=1 STATUS=trialing"
  task set_status: :environment do
    abort_unless_dev!
    space = Space.find(ENV.fetch("SPACE_ID"))
    sub   = space.subscription or abort("Space has no subscription")

    sub.update!(status: ENV.fetch("STATUS"))
    puts "#{space.name} subscription → #{sub.status}"
  end

  desc "Add credits to a space. Usage: rake dev:add_credits SPACE_ID=1 AMOUNT=100"
  task add_credits: :environment do
    abort_unless_dev!
    space  = Space.find(ENV.fetch("SPACE_ID"))
    amount = ENV.fetch("AMOUNT").to_i
    credit = space.message_credit || space.create_message_credit!(balance: 0, monthly_quota_remaining: 0)

    credit.update!(balance: credit.balance + amount)
    puts "#{space.name} credits: #{credit.balance} (+#{amount})"
  end

  desc "Seed WhatsApp conversations for a space. Usage: rake dev:seed_conversations SPACE_ID=1"
  task seed_conversations: :environment do
    abort_unless_dev!
    space     = Space.find(ENV.fetch("SPACE_ID"))
    customers = space.customers.limit(3).to_a

    if customers.empty?
      abort "Space #{space.id} has no customers. Create some first."
    end

    customers.each_with_index do |customer, i|
      phone = customer.phone.presence || "+551199900000#{i}"
      wa_id = phone.delete("+")

      conv = space.whatsapp_conversations.find_or_initialize_by(wa_id: wa_id)
      if conv.new_record?
        active_session = i.even?
        conv.assign_attributes(
          customer: customer,
          customer_phone: phone,
          customer_name: customer.name,
          last_message_at: active_session ? 5.minutes.ago : 2.days.ago,
          session_expires_at: active_session ? 23.hours.from_now : 2.days.ago,
          unread: active_session
        )
        conv.save!

        conv.whatsapp_messages.create!(
          wamid: "wamid.seed_out_#{conv.id}",
          direction: :outbound,
          body: "Olá #{customer.name}! Confirma sua consulta?",
          message_type: "text",
          status: :read,
          metadata: {},
          created_at: conv.last_message_at - 2.hours
        )

        conv.whatsapp_messages.create!(
          wamid: "wamid.seed_in_#{conv.id}",
          direction: :inbound,
          body: active_session ? "Sim, confirmo!" : "Obrigado!",
          message_type: "text",
          status: :delivered,
          metadata: {},
          created_at: conv.last_message_at
        )

        status = active_session ? "active session" : "expired session"
        puts "  Created conversation with #{customer.name} (#{status})"
      else
        puts "  Skipped #{customer.name} (conversation already exists)"
      end
    end
  end

  desc "Reset a space to trial state. Usage: rake dev:reset_trial SPACE_ID=1"
  task reset_trial: :environment do
    abort_unless_dev!
    space = Space.find(ENV.fetch("SPACE_ID"))
    plan  = Billing::Plan.trial_plan

    sub = space.subscription || space.build_subscription
    sub.update!(
      billing_plan: plan,
      status: :trialing,
      current_period_start: Time.current,
      current_period_end: 14.days.from_now,
      trial_ends_at: 14.days.from_now
    )

    credit = space.message_credit || space.create_message_credit!(balance: 0, monthly_quota_remaining: 0)
    credit.update!(balance: 0, monthly_quota_remaining: plan.whatsapp_monthly_quota.to_i)

    puts "#{space.name} → #{plan.name} trial (14 days), quota: #{credit.monthly_quota_remaining}"
  end

  def abort_unless_dev!
    abort "This task is only available in development." unless Rails.env.development?
  end
end
