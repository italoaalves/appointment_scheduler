# Only allow seeds in development or test
unless Rails.env.development? || Rails.env.test?
  puts "Seeds are disabled in #{Rails.env} environment."
  exit
end

puts "🌱 Seeding database..."

Appointment.destroy_all
User.destroy_all

# ---- USERS ----

admin = User.create!(
  name: "Dr. Secretary",
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: :admin,
  phone_number: "+5511999999999"
)

client1 = User.create!(
  name: "John Client",
  email: "client1@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: :client,
  phone_number: "+5511888888888"
)

client2 = User.create!(
  name: "Mary Client",
  email: "client2@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: :client,
  phone_number: "+5511777777777"
)

# ---- APPOINTMENTS ----

Appointment.create!(
  user: client1,
  requested_at: 2.days.from_now,
  status: :requested,
)

Appointment.create!(
  user: client1,
  requested_at: 5.days.from_now,
  scheduled_at: 5.days.from_now,
  status: :confirmed,
)

Appointment.create!(
  user: client2,
  requested_at: 3.days.from_now,
  status: :denied,
)

puts "✅ Seed completed!"
puts "Admin login: admin@example.com / password123"
puts "Client login: client1@example.com / password123"