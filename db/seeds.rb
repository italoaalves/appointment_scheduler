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
client1 = space.clients.create!(name: "John Client", phone: "+5511888888888", address: "Rua A, 1")
client2 = space.clients.create!(name: "Mary Client", phone: "+5511777777777", address: "Rua B, 2")

# ---- APPOINTMENTS (belong to space and client) ----
space.appointments.create!(
  client: client1,
  requested_at: 2.days.from_now,
  status: :requested
)
space.appointments.create!(
  client: client1,
  requested_at: 5.days.from_now,
  scheduled_at: 5.days.from_now,
  status: :confirmed
)
space.appointments.create!(
  client: client2,
  requested_at: 3.days.from_now,
  status: :denied
)

puts "✅ Seed completed!"
puts "SaaS admin: admin@example.com / password123"
puts "Manager (tenant owner): manager@example.com / password123"
puts "Secretary: secretary@example.com / password123"
