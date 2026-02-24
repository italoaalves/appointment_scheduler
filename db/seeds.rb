# Only allow seeds in development or test
unless Rails.env.development? || Rails.env.test?
  puts "Seeds are disabled in #{Rails.env} environment."
  exit
end

puts "🌱 Seeding database..."

Appointment.destroy_all
Customer.destroy_all
UserPreference.destroy_all
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
past_dates = [base_date - 14, base_date - 10, base_date - 5]
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

puts "✅ Seed completed!"
puts "SaaS admin: admin@example.com / password123"
puts "Manager (tenant owner): manager@example.com / password123"
puts "Secretary: secretary@example.com / password123"
