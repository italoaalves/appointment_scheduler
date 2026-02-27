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

ActiveRecord::Schema[8.0].define(version: 2026_02_27_032748) do
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
    t.datetime "discarded_at"
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_client_scheduled_at"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["discarded_at"], name: "index_appointments_on_discarded_at"
    t.index ["space_id", "scheduled_at"], name: "index_appointments_unique_active_slot", unique: true, where: "((status = ANY (ARRAY[0, 1, 3])) AND (scheduled_at IS NOT NULL) AND (discarded_at IS NULL))"
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

  create_table "billing_events", force: :cascade do |t|
    t.bigint "space_id", null: false
    t.bigint "subscription_id"
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "actor_id"
    t.datetime "created_at", null: false
    t.index ["event_type"], name: "index_billing_events_on_event_type"
    t.index ["space_id", "created_at"], name: "index_billing_events_on_space_id_and_created_at"
    t.index ["space_id"], name: "index_billing_events_on_space_id"
    t.index ["subscription_id"], name: "index_billing_events_on_subscription_id"
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
    t.index "space_id, lower((email)::text)", name: "index_customers_on_space_id_lower_email", where: "(email IS NOT NULL)"
    t.index ["space_id"], name: "index_customers_on_space_id"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "message_credits", force: :cascade do |t|
    t.bigint "space_id", null: false
    t.integer "balance", default: 0, null: false
    t.integer "monthly_quota_remaining", default: 0, null: false
    t.datetime "quota_refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["space_id"], name: "index_message_credits_on_space_id"
    t.index ["space_id"], name: "index_message_credits_on_space_id_unique", unique: true
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
    t.index ["recipient_id", "created_at"], name: "index_messages_on_recipient_id_created_at"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["sender_id", "created_at"], name: "index_messages_on_sender_id_created_at"
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
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.bigint "space_id", null: false
    t.string "asaas_payment_id", null: false
    t.integer "amount_cents", null: false
    t.integer "payment_method", null: false
    t.integer "status", default: 0, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asaas_payment_id"], name: "index_payments_on_asaas_payment_id", unique: true
    t.index ["space_id"], name: "index_payments_on_space_id"
    t.index ["subscription_id", "created_at"], name: "index_payments_on_subscription_id_and_created_at"
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
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

  create_table "space_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "space_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["space_id"], name: "index_space_memberships_on_space_id"
    t.index ["user_id", "space_id"], name: "index_space_memberships_on_user_id_and_space_id", unique: true
    t.index ["user_id"], name: "index_space_memberships_on_user_id"
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
    t.bigint "owner_id"
    t.integer "cancellation_min_hours_before"
    t.integer "reschedule_min_hours_before"
    t.integer "request_max_days_ahead"
    t.integer "request_min_hours_ahead"
    t.index ["owner_id"], name: "index_spaces_on_owner_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "space_id", null: false
    t.string "plan_id", null: false
    t.integer "status", default: 0, null: false
    t.string "asaas_subscription_id"
    t.string "asaas_customer_id"
    t.integer "payment_method"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "trial_ends_at"
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pending_plan_id"
    t.index ["asaas_subscription_id"], name: "index_subscriptions_on_asaas_subscription_id", unique: true, where: "(asaas_subscription_id IS NOT NULL)"
    t.index ["space_id"], name: "index_subscriptions_on_space_id"
    t.index ["space_id"], name: "index_subscriptions_on_space_id_active", unique: true, where: "(status <> 4)"
    t.index ["status", "trial_ends_at"], name: "index_subscriptions_on_status_and_trial_ends_at"
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
    t.integer "system_role"
    t.string "role", default: "", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "spaces"
  add_foreign_key "availability_windows", "availability_schedules"
  add_foreign_key "billing_events", "spaces"
  add_foreign_key "billing_events", "subscriptions"
  add_foreign_key "customers", "spaces"
  add_foreign_key "customers", "users"
  add_foreign_key "message_credits", "spaces"
  add_foreign_key "messages", "users", column: "recipient_id"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "payments", "spaces"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "personalized_scheduling_links", "spaces"
  add_foreign_key "scheduling_links", "spaces"
  add_foreign_key "space_memberships", "spaces"
  add_foreign_key "space_memberships", "users"
  add_foreign_key "spaces", "users", column: "owner_id"
  add_foreign_key "subscriptions", "spaces"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "user_preferences", "users"
end
