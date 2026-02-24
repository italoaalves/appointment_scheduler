# Only allow seeds in development or test
unless Rails.env.development? || Rails.env.test?
  puts "Seeds are disabled in #{Rails.env} environment."
  exit
end

puts "🌱 Seeding database..."

Appointment.destroy_all
Client.destroy_all
User.destroy_all
Space.destroy_all

# ---- SAAS ADMIN (no space) ----
admin = User.create!(
  name: "Platform Admin",
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: :admin,
  phone_number: "+5511999999999"
)

# ---- TENANT: SPACE + MANAGER + SECRETARY ----
manager = User.create!(
  name: "Dr. Owner",
  email: "manager@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: :manager,
  phone_number: "+5511988888888"
)
# ensure_space_for_manager callback creates Space and assigns it
space = manager.reload.space

secretary = User.create!(
  name: "Jane Secretary",
  email: "secretary@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: :secretary,
  phone_number: "+5511977777777",
  space_id: space.id
)

# ---- CLIENTS (belong to space) ----
clients = [
  space.clients.create!(name: "John Client", phone: "+5511888888888", address: "Rua A, 1"),
  space.clients.create!(name: "Mary Client", phone: "+5511777777777", address: "Rua B, 2"),
  space.clients.create!(name: "Ana Silva", phone: "+5511666666666", address: "Rua C, 3"),
  space.clients.create!(name: "Pedro Santos", phone: "+5511555555555", address: "Rua D, 4"),
  space.clients.create!(name: "Maria Costa", phone: "+5511444444444", address: "Rua E, 5")
]

# ---- APPOINTMENTS (30 total, mixed statuses and dates) ----
statuses = %i[pending confirmed pending confirmed cancelled rescheduled]
base_date = Time.current

30.times do |i|
  client = clients[i % clients.size]
  days_offset = (i - 15) # range: -15 to +14 days
  scheduled_at = base_date + days_offset.days + (i % 8).hours
  status = statuses[i % statuses.size]

  space.appointments.create!(
    client: client,
    requested_at: scheduled_at - 1.day,
    scheduled_at: scheduled_at,
    status: status
  )
end

puts "✅ Seed completed!"
puts "SaaS admin: admin@example.com / password123"
puts "Manager (tenant owner): manager@example.com / password123"
puts "Secretary: secretary@example.com / password123"
