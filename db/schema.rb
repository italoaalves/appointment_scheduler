# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_26_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.datetime "requested_at"
    t.datetime "scheduled_at"
    t.datetime "rescheduled_from"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_id"
    t.bigint "space_id", null: false
    t.integer "duration_minutes"
    t.datetime "finished_at"
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_client_scheduled_at"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["space_id", "status", "scheduled_at"], name: "index_appointments_on_space_status_scheduled_at"
    t.index ["space_id"], name: "index_appointments_on_space_id"
  end

  create_table "availability_schedules", force: :cascade do |t|
    t.string "schedulable_type", null: false
    t.bigint "schedulable_id", null: false
    t.string "timezone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["schedulable_type", "schedulable_id"], name: "index_availability_schedules_on_schedulable"
  end

  create_table "availability_windows", force: :cascade do |t|
    t.bigint "availability_schedule_id", null: false
    t.integer "weekday", null: false
    t.time "opens_at", null: false
    t.time "closes_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["availability_schedule_id", "weekday"], name: "index_availability_windows_on_schedule_weekday"
    t.index ["availability_schedule_id"], name: "index_availability_windows_on_availability_schedule_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "space_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.bigint "user_id"
    t.index ["space_id"], name: "index_customers_on_space_id"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "sender_id", null: false
    t.bigint "recipient_id", null: false
    t.text "content"
    t.integer "channel", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "messageable_type", null: false
    t.bigint "messageable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["messageable_type", "messageable_id"], name: "index_messages_on_messageable"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.text "body"
    t.boolean "read", default: false
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "personalized_scheduling_links", force: :cascade do |t|
    t.bigint "space_id", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_personalized_scheduling_links_on_slug", unique: true
    t.index ["space_id"], name: "index_personalized_scheduling_links_on_space_id"
  end

  create_table "scheduling_links", force: :cascade do |t|
    t.bigint "space_id", null: false
    t.string "token", null: false
    t.integer "link_type", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "used_at"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["space_id"], name: "index_scheduling_links_on_space_id"
    t.index ["token"], name: "index_scheduling_links_on_token", unique: true
  end

  create_table "spaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "timezone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "business_type"
    t.text "address"
    t.string "phone"
    t.string "email"
    t.text "business_hours"
    t.string "instagram_url"
    t.string "facebook_url"
    t.integer "slot_duration_minutes", default: 30, null: false
    t.jsonb "business_hours_schedule", default: {}
    t.integer "personalized_slug_changes_count", default: 0, null: false
    t.datetime "personalized_slug_last_changed_at"
    t.text "booking_success_message"
  end

  create_table "user_permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "permission", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "permission"], name: "index_user_permissions_on_user_id_and_permission", unique: true
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "locale", default: "pt-BR", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "space_id"
    t.integer "system_role"
    t.string "role", default: "", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["space_id"], name: "index_users_on_space_id"
  end

  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "spaces"
  add_foreign_key "availability_windows", "availability_schedules"
  add_foreign_key "customers", "spaces"
  add_foreign_key "customers", "users"
  add_foreign_key "messages", "users", column: "recipient_id"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "personalized_scheduling_links", "spaces"
  add_foreign_key "scheduling_links", "spaces"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "users", "spaces"
end
