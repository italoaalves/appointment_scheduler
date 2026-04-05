# Only allow seeds in development or test
unless Rails.env.development? || Rails.env.test?
  puts "Seeds are disabled in #{Rails.env} environment."
  exit
end

puts "🌱 Seeding database..."

ConversationMessage.destroy_all
Conversation.destroy_all
Billing::BillingEvent.destroy_all
Billing::Payment.destroy_all
Billing::Subscription.destroy_all
Billing::MessageCredit.destroy_all
Billing::Plan.destroy_all
Billing::CreditBundle.destroy_all
WhatsappPhoneNumber.destroy_all
Appointment.destroy_all
Customer.destroy_all
UserPreference.destroy_all
Space.update_all(owner_id: nil)  # break circular FK (spaces.owner_id → users)
User.destroy_all
Space.destroy_all

# ---- CREDIT BUNDLES ----
Billing::CreditBundle.create!([
  { name: "50 credits",  amount: 50,  price_cents: 2500, position: 0 },
  { name: "100 credits", amount: 100, price_cents: 4500, position: 1 },
  { name: "200 credits", amount: 200, price_cents: 8000, position: 2 }
])

# ---- BILLING PLANS ----
Billing::Plan.create!(
  slug: "essential", name: "Essential", price_cents: 4999,
  max_team_members: 1, max_customers: 100, max_scheduling_links: 3,
  whatsapp_monthly_quota: 0, features: [], allowed_payment_methods: [],
  position: 1, public: true, highlighted: false, trial_default: false, active: true
)

Billing::Plan.create!(
  slug: "pro", name: "Pro", price_cents: 11990,
  max_team_members: 5, max_customers: nil, max_scheduling_links: nil,
  whatsapp_monthly_quota: 200,
  features: %w[personalized_booking_page custom_appointment_policies whatsapp_included_quota],
  allowed_payment_methods: [],
  position: 2, public: true, highlighted: true, trial_default: true, active: true
)

Billing::Plan.create!(
  slug: "enterprise", name: "Enterprise", price_cents: 29999,
  max_team_members: nil, max_customers: nil, max_scheduling_links: nil,
  whatsapp_monthly_quota: nil,
  features: %w[personalized_booking_page custom_appointment_policies whatsapp_included_quota priority_support],
  allowed_payment_methods: %w[credit_card],
  position: 3, public: true, highlighted: false, trial_default: false, active: true
)

# ---- WHATSAPP PHONE NUMBER (system bot) ----
WhatsappPhoneNumber.find_or_create_by!(phone_number_id: "SEED_PHONE_NUMBER_ID") do |pn|
  pn.display_number = "+55 11 99999-0000"
  pn.waba_id = "SEED_WABA_ID"
  pn.verified_name = "Platform Bot"
  pn.status = :active
end

# ---- SAAS ADMIN (no space) ----
admin = User.create!(
  name: "Platform Admin",
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  system_role: :super_admin,
  phone_number: "+5511999999999",
  confirmed_at: Time.current
)

# ---- TENANT: SPACE + MANAGER + SECRETARY ----
manager = User.new(
  name: "Dr. Owner",
  email: "manager@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: "Manager",
  phone_number: "+5511988888888",
  confirmed_at: Time.current
)
%w[access_space_dashboard manage_space manage_team manage_customers manage_appointments destroy_appointments manage_scheduling_links manage_personalized_links own_space].each do |p|
  manager.user_permissions.build(permission: p)
end
manager.save!
space = manager.reload.space

# ---- BILLING: upgrade auto-created trial to active Pro subscription ----
subscription = space.subscription
subscription.update!(
  status: :active,
  billing_plan: Billing::Plan.find_by_slug!("pro"),
  current_period_start: Time.current,
  current_period_end: 30.days.from_now,
  trial_ends_at: nil
)

credit = space.message_credit
credit.update!(
  balance: 25,
  monthly_quota_remaining: 180
)

Billing::Payment.create!(
  subscription: subscription,
  space: space,
  asaas_payment_id: "pay_seed_001",
  amount_cents: 9900,
  payment_method: :pix,
  status: :confirmed,
  paid_at: 2.days.ago
)

Billing::BillingEvent.create!(
  space: space,
  subscription: subscription,
  event_type: "subscription.activated",
  metadata: { plan_id: "pro", payment_method: "pix" }
)

Billing::BillingEvent.create!(
  space: space,
  subscription: subscription,
  event_type: "credits.purchased",
  metadata: { amount: 25 }
)

# Default timezone and business hours (Mon–Fri 9:00–17:00)
space.update!(timezone: "America/Sao_Paulo")
schedule = space.create_availability_schedule!
[ 1, 2, 3, 4, 5 ].each do |wday|
  schedule.availability_windows.create!(
    weekday: wday,
    opens_at: Time.zone.parse("2000-01-01 09:00"),
    closes_at: Time.zone.parse("2000-01-01 17:00")
  )
end
schedule.touch # Triggers after_save to cache business_hours

secretary = User.new(
  name: "Jane Secretary",
  email: "secretary@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: "Secretary",
  phone_number: "+5511977777777",
  space_id: space.id,
  confirmed_at: Time.current
)
%w[access_space_dashboard manage_customers manage_appointments manage_scheduling_links].each do |p|
  secretary.user_permissions.build(permission: p)
end
secretary.save!

# ---- CUSTOMERS (belong to space) ----
customers = [
  space.customers.create!(name: "John Customer", phone: "+5511888888888", address: "Rua A, 1"),
  space.customers.create!(name: "Mary Customer", phone: "+5511777777777", address: "Rua B, 2"),
  space.customers.create!(name: "Ana Silva", phone: "+5511666666666", address: "Rua C, 3"),
  space.customers.create!(name: "Pedro Santos", phone: "+5511555555555", address: "Rua D, 4"),
  space.customers.create!(name: "Maria Costa", phone: "+5511444444444", address: "Rua E, 5")
]

# ---- APPOINTMENTS (varied: full days, half days, empty days) ----
# Business hours roughly 9–17; we use slots at 9, 10, 11, 12, 14, 15, 16
statuses = %i[pending confirmed pending confirmed cancelled rescheduled]
tz = Time.zone
base_date = tz.today

# Define day types: empty (0), half (2–3), full (6–7 appointments)
# Days from -7 to +14 relative to today
day_configs = {
  -7 => 0,   # empty
  -6 => 7,   # full
  -5 => 0,   # empty
  -4 => 3,   # half
  -3 => 7,   # full
  -2 => 2,   # half
  -1 => 5,   # half-full
  0  => 8,   # full (today)
  1  => 0,   # empty
  2  => 4,   # half
  3  => 0,   # empty
  4  => 6,   # full
  5  => 2,   # half
  6  => 0,   # empty (likely Sunday)
  7  => 7,   # full
  8  => 3,   # half
  9  => 0,   # empty
  10 => 5,   # half-full
  11 => 0,   # empty
  12 => 6,   # full
  13 => 2,   # half
  14 => 0    # empty
}

slot_hours = [ 8, 9, 10, 11, 12, 14, 15, 16 ]

day_configs.each do |days_offset, count|
  next if count.zero?

  date = base_date + days_offset
  slots_to_use = slot_hours.first(count)
  slots_to_use.each_with_index do |hour, i|
    scheduled_at = tz.local(date.year, date.month, date.day, hour, 0)
    customer = customers[i % customers.size]
    status = statuses[i % statuses.size]

    space.appointments.create!(
      customer: customer,
      requested_at: scheduled_at - 1.day,
      scheduled_at: scheduled_at,
      status: status
    )
  end
end

# ---- PAST APPOINTMENTS: NO-SHOW + FINISHED ----
# A few appointments in the past with no_show and finished status
past_dates = [ base_date - 14, base_date - 10, base_date - 5 ]
past_dates.each_with_index do |date, i|
  scheduled_at = tz.local(date.year, date.month, date.day, 10 + i, 0)
  customer = customers[i % customers.size]
  status = i.even? ? :no_show : :finished

  attrs = {
    customer: customer,
    requested_at: scheduled_at - 1.day,
    scheduled_at: scheduled_at,
    status: status
  }
  attrs[:finished_at] = scheduled_at + 45.minutes if status == :finished

  space.appointments.create!(attrs)
end

# ---- INBOX: CONVERSATIONS + MESSAGES ----
# Covers a wide range of visual states for inbox development/testing.
now = Time.current

# Helper to build a conversation with messages
def seed_conversation(space:, customer:, channel:, status:, priority:, assigned_to: nil,
                      contact_name: nil, subject: nil, unread: false, sla_breached: false,
                      session_active: false, messages: [], created_offset: 0)
  ext_id = "seed_#{channel}_#{SecureRandom.hex(6)}"
  contact = contact_name || customer&.name || "Unknown"
  phone   = customer&.phone || "+55119#{rand(10_000_000..99_999_999)}"

  session_expires = session_active ? (Time.current + 20.hours) : (Time.current - 2.hours)
  last_msg        = messages.last
  last_body       = last_msg&.fetch(:body, nil)
  last_at         = Time.current - created_offset.hours + messages.size.minutes

  conv = space.conversations.create!(
    customer: customer,
    channel: channel,
    status: status,
    priority: priority,
    assigned_to: assigned_to,
    contact_identifier: phone,
    contact_name: contact,
    subject: subject,
    external_id: ext_id,
    unread: unread,
    sla_breached: sla_breached,
    session_expires_at: session_expires,
    last_message_body: last_body,
    last_message_at: last_at,
    created_at: Time.current - created_offset.hours,
    updated_at: last_at
  )

  messages.each_with_index do |msg, i|
    conv.conversation_messages.create!(
      direction: msg[:direction],
      body: msg[:body],
      status: msg.fetch(:status, :delivered),
      message_type: msg.fetch(:type, "text"),
      sent_by: msg[:direction] == :outbound ? msg.fetch(:sent_by, nil) : nil,
      created_at: Time.current - created_offset.hours + i.minutes,
      updated_at: Time.current - created_offset.hours + i.minutes
    )
  end

  conv
end

# 1. Unread, needs reply — customer sent a question, no one replied yet
seed_conversation(
  space: space, customer: customers[0], channel: :whatsapp,
  status: :needs_reply, priority: :high, unread: true,
  messages: [
    { direction: :inbound,  body: "Olá! Gostaria de remarcar minha consulta de amanhã." },
    { direction: :inbound,  body: "Consigo para sexta-feira?" }
  ],
  created_offset: 2
)

# 2. Open — back-and-forth conversation, assigned to manager
seed_conversation(
  space: space, customer: customers[1], channel: :whatsapp,
  status: :open, priority: :normal, assigned_to: manager, unread: false,
  session_active: true,
  messages: [
    { direction: :inbound,  body: "Boa tarde! Quero agendar uma avaliação." },
    { direction: :outbound, body: "Claro! Temos horários na quarta ou quinta. Qual prefere?", sent_by: manager },
    { direction: :inbound,  body: "Quarta está ótimo, às 10h." },
    { direction: :outbound, body: "Perfeito! Agendei para quarta às 10h. Até lá!", sent_by: manager }
  ],
  created_offset: 5
)

# 3. Pending — waiting on customer response after outbound message
seed_conversation(
  space: space, customer: customers[2], channel: :whatsapp,
  status: :pending, priority: :normal, assigned_to: secretary, unread: false,
  session_active: true,
  messages: [
    { direction: :inbound,  body: "Preciso de informações sobre os planos de tratamento." },
    { direction: :outbound, body: "Olá Ana! Posso te enviar um documento com os detalhes. Qual seu e-mail?", sent_by: secretary }
  ],
  created_offset: 8
)

# 4. Resolved — completed conversation, past
seed_conversation(
  space: space, customer: customers[3], channel: :whatsapp,
  status: :resolved, priority: :low, unread: false,
  messages: [
    { direction: :inbound,  body: "Bom dia! Gostaria de cancelar meu agendamento." },
    { direction: :outbound, body: "Olá Pedro, cancelamento feito. Até logo!", sent_by: manager, status: :read }
  ],
  created_offset: 48
)

# 5. SLA breached — high priority, no response for a long time
seed_conversation(
  space: space, customer: customers[4], channel: :whatsapp,
  status: :needs_reply, priority: :urgent, unread: true, sla_breached: true,
  messages: [
    { direction: :inbound, body: "URGENTE: tive uma reação após o procedimento de ontem. Preciso falar com o médico!" }
  ],
  created_offset: 6
)

# 6. Unassigned, open — no agent assigned yet
seed_conversation(
  space: space, customer: customers[0], channel: :whatsapp,
  status: :open, priority: :normal, unread: true,
  messages: [
    { direction: :inbound, body: "Oi, vocês aceitam convênio Unimed?" },
    { direction: :inbound, body: "Aguardo resposta, obrigado." }
  ],
  created_offset: 1
)

# 7. Long conversation — many turns, session active
seed_conversation(
  space: space, customer: customers[1], channel: :whatsapp,
  status: :open, priority: :normal, assigned_to: manager, unread: false,
  session_active: true,
  messages: [
    { direction: :inbound,  body: "Olá, preciso de ajuda com o histórico de consultas." },
    { direction: :outbound, body: "Claro! Poderia me informar seu CPF para localizar o cadastro?", sent_by: manager },
    { direction: :inbound,  body: "123.456.789-00" },
    { direction: :outbound, body: "Encontrei seu cadastro. Você tem 3 consultas registradas.", sent_by: manager },
    { direction: :inbound,  body: "Pode me dizer as datas?" },
    { direction: :outbound, body: "12/01, 15/02 e 10/03.", sent_by: manager },
    { direction: :inbound,  body: "Obrigado! Mais uma coisa: preciso de um atestado." },
    { direction: :outbound, body: "Para atestado você precisa agendar uma consulta presencial.", sent_by: manager },
    { direction: :inbound,  body: "Ok, vou ligar para agendar. Muito obrigado!" },
    { direction: :outbound, body: "Fico à disposição!", sent_by: manager, status: :read }
  ],
  created_offset: 24
)

# 8. Needs reply — inbound from unknown (no customer linked)
seed_conversation(
  space: space, customer: nil, channel: :whatsapp,
  status: :needs_reply, priority: :normal, unread: true,
  contact_name: "Desconhecido",
  messages: [
    { direction: :inbound, body: "Olá, vi o anúncio no Instagram. Como funciona o agendamento online?" }
  ],
  created_offset: 3
)

# 9. Closed — old resolved conversation
seed_conversation(
  space: space, customer: customers[2], channel: :whatsapp,
  status: :closed, priority: :low, unread: false,
  messages: [
    { direction: :inbound,  body: "Tudo bem? Quero confirmar minha consulta de sexta." },
    { direction: :outbound, body: "Confirmo! Sexta às 14h. Até lá.", sent_by: secretary, status: :read }
  ],
  created_offset: 72
)

# 10. Failed outbound — message failed to deliver
seed_conversation(
  space: space, customer: customers[3], channel: :whatsapp,
  status: :needs_reply, priority: :high, unread: false,
  messages: [
    { direction: :inbound,  body: "Preciso do resultado dos exames." },
    { direction: :outbound, body: "Enviando agora...", sent_by: manager, status: :failed }
  ],
  created_offset: 4
)

# 11. Automated — bot/automation flow, no human yet
seed_conversation(
  space: space, customer: customers[4], channel: :whatsapp,
  status: :automated, priority: :low, unread: false,
  messages: [
    { direction: :inbound,  body: "1" },
    { direction: :outbound, body: "Olá! Sou o assistente virtual. Digite 1 para agendar, 2 para cancelar." },
    { direction: :inbound,  body: "1" },
    { direction: :outbound, body: "Ótimo! Qual data prefere? (dd/mm/aaaa)" }
  ],
  created_offset: 1
)

# 12. Needs reply — long message body (truncation test)
seed_conversation(
  space: space, customer: customers[0], channel: :whatsapp,
  status: :needs_reply, priority: :normal, unread: true,
  messages: [
    { direction: :inbound, body: "Bom dia doutor, estou escrevendo porque ontem após a consulta comecei a sentir uns sintomas estranhos: dor de cabeça persistente, enjoo e uma sensação de formigamento no braço esquerdo. Gostaria de saber se devo me preocupar ou se isso é normal dado o procedimento que fiz. Fico no aguardo, obrigado." }
  ],
  created_offset: 1
)

puts "✅ Seed completed!"
puts "SaaS admin: admin@example.com / password123"
puts "Manager (tenant owner): manager@example.com / password123"
puts "Secretary: secretary@example.com / password123"
puts "Billing: Active Pro subscription for #{space.name}"
puts "Credits: #{credit.balance} purchased + #{credit.monthly_quota_remaining} monthly quota"
puts "Inbox: 12 conversations seeded (needs_reply, open, pending, resolved, closed, automated, SLA breached, failed message, long body)"
