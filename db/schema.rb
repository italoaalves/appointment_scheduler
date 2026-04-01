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

ActiveRecord::Schema[8.1].define(version: 2026_04_01_011054) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.datetime "discarded_at"
    t.integer "duration_minutes"
    t.datetime "finished_at"
    t.datetime "requested_at"
    t.datetime "rescheduled_from"
    t.datetime "scheduled_at"
    t.bigint "space_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_client_scheduled_at"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["discarded_at"], name: "index_appointments_on_discarded_at"
    t.index ["space_id", "scheduled_at"], name: "index_appointments_unique_active_slot", unique: true, where: "((status = ANY (ARRAY[0, 1, 3])) AND (scheduled_at IS NOT NULL) AND (discarded_at IS NULL))"
    t.index ["space_id", "status", "scheduled_at"], name: "index_appointments_on_space_status_scheduled_at"
    t.index ["space_id"], name: "index_appointments_on_space_id"
  end

  create_table "availability_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "schedulable_id", null: false
    t.string "schedulable_type", null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["schedulable_type", "schedulable_id"], name: "index_availability_schedules_on_schedulable"
  end

  create_table "availability_windows", force: :cascade do |t|
    t.bigint "availability_schedule_id", null: false
    t.time "closes_at", null: false
    t.datetime "created_at", null: false
    t.time "opens_at", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["availability_schedule_id", "weekday"], name: "index_availability_windows_on_schedule_weekday"
    t.index ["availability_schedule_id"], name: "index_availability_windows_on_availability_schedule_id"
  end

  create_table "billing_events", force: :cascade do |t|
    t.integer "actor_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "space_id", null: false
    t.bigint "subscription_id"
    t.index "((metadata ->> 'asaas_payment_id'::text))", name: "idx_billing_events_metadata_asaas_payment_id", where: "((metadata ->> 'asaas_payment_id'::text) IS NOT NULL)"
    t.index ["event_type"], name: "index_billing_events_on_event_type"
    t.index ["space_id", "created_at"], name: "index_billing_events_on_space_id_and_created_at"
    t.index ["space_id"], name: "index_billing_events_on_space_id"
    t.index ["subscription_id"], name: "index_billing_events_on_subscription_id"
  end

  create_table "billing_plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "allowed_payment_methods", default: [], null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "features", default: [], null: false
    t.boolean "highlighted", default: false, null: false
    t.integer "max_customers"
    t.integer "max_scheduling_links"
    t.integer "max_team_members"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents", default: 0, null: false
    t.boolean "public", default: true, null: false
    t.string "slug", null: false
    t.boolean "trial_default", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "whatsapp_monthly_quota"
    t.index ["position"], name: "index_billing_plans_on_position"
    t.index ["slug"], name: "index_billing_plans_on_slug", unique: true
    t.index ["trial_default"], name: "index_billing_plans_on_trial_default", unique: true, where: "(trial_default = true)"
  end

  create_table "credit_bundles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_credit_bundles_on_position"
  end

  create_table "credit_purchases", force: :cascade do |t|
    t.integer "actor_id"
    t.integer "amount", null: false
    t.string "asaas_payment_id"
    t.string "bank_slip_url"
    t.datetime "created_at", null: false
    t.bigint "credit_bundle_id", null: false
    t.string "invoice_url"
    t.text "pix_payload"
    t.text "pix_qr_code_base64"
    t.integer "price_cents", null: false
    t.bigint "space_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["asaas_payment_id"], name: "index_credit_purchases_on_asaas_payment_id", unique: true, where: "(asaas_payment_id IS NOT NULL)"
    t.index ["credit_bundle_id"], name: "index_credit_purchases_on_credit_bundle_id"
    t.index ["space_id", "status"], name: "index_credit_purchases_on_space_id_and_status"
    t.index ["space_id"], name: "index_credit_purchases_on_space_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.bigint "space_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index "space_id, lower((email)::text)", name: "index_customers_on_space_id_lower_email", where: "(email IS NOT NULL)"
    t.index ["space_id"], name: "index_customers_on_space_id"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "message_credits", force: :cascade do |t|
    t.integer "balance", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "monthly_quota_remaining", default: 0, null: false
    t.datetime "quota_refreshed_at"
    t.bigint "space_id", null: false
    t.datetime "updated_at", null: false
    t.index ["space_id"], name: "index_message_credits_on_space_id"
    t.index ["space_id"], name: "index_message_credits_on_space_id_unique", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "channel", default: 0, null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "messageable_id", null: false
    t.string "messageable_type", null: false
    t.bigint "recipient_id", null: false
    t.bigint "sender_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["messageable_type", "messageable_id"], name: "index_messages_on_messageable"
    t.index ["recipient_id", "created_at"], name: "index_messages_on_recipient_id_created_at"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["sender_id", "created_at"], name: "index_messages_on_sender_id_created_at"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "event_type", default: "", null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.boolean "read", default: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_type"], name: "index_notifications_on_event_type"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "asaas_payment_id", null: false
    t.string "asaas_status"
    t.datetime "created_at", null: false
    t.date "due_date"
    t.string "invoice_url"
    t.datetime "paid_at"
    t.integer "payment_method", null: false
    t.bigint "space_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["asaas_payment_id"], name: "index_payments_on_asaas_payment_id", unique: true
    t.index ["space_id"], name: "index_payments_on_space_id"
    t.index ["status", "payment_method", "due_date"], name: "index_payments_on_status_method_due_date"
    t.index ["subscription_id", "created_at"], name: "index_payments_on_subscription_id_and_created_at"
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
  end

  create_table "personalized_scheduling_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "slug", null: false
    t.bigint "space_id", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_personalized_scheduling_links_on_slug", unique: true
    t.index ["space_id"], name: "index_personalized_scheduling_links_on_space_id"
  end

  create_table "scheduling_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "link_type", default: 0, null: false
    t.string "name"
    t.bigint "space_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["space_id"], name: "index_scheduling_links_on_space_id"
    t.index ["token"], name: "index_scheduling_links_on_token", unique: true
  end

  create_table "space_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "space_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["space_id"], name: "index_space_memberships_on_space_id"
    t.index ["user_id", "space_id"], name: "index_space_memberships_on_user_id_and_space_id", unique: true
    t.index ["user_id"], name: "index_space_memberships_on_user_id"
  end

  create_table "spaces", force: :cascade do |t|
    t.text "address"
    t.text "booking_success_message"
    t.text "business_hours"
    t.jsonb "business_hours_schedule", default: {}
    t.string "business_type"
    t.integer "cancellation_min_hours_before"
    t.datetime "completed_onboarding_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "facebook_url"
    t.string "instagram_url"
    t.string "name", null: false
    t.datetime "onboarding_nudge_sent_at"
    t.integer "onboarding_step", default: 0, null: false
    t.bigint "owner_id"
    t.integer "personalized_slug_changes_count", default: 0, null: false
    t.datetime "personalized_slug_last_changed_at"
    t.string "phone"
    t.integer "request_max_days_ahead"
    t.integer "request_min_hours_ahead"
    t.integer "reschedule_min_hours_before"
    t.integer "slot_duration_minutes", default: 30, null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_spaces_on_owner_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "asaas_customer_id"
    t.string "asaas_subscription_id"
    t.bigint "billing_plan_id", null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.integer "payment_method"
    t.bigint "pending_billing_plan_id"
    t.bigint "space_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["asaas_subscription_id"], name: "index_subscriptions_on_asaas_subscription_id", unique: true, where: "(asaas_subscription_id IS NOT NULL)"
    t.index ["billing_plan_id"], name: "index_subscriptions_on_billing_plan_id"
    t.index ["pending_billing_plan_id"], name: "index_subscriptions_on_pending_billing_plan_id"
    t.index ["space_id"], name: "index_subscriptions_on_space_id"
    t.index ["space_id"], name: "index_subscriptions_on_space_id_active", unique: true, where: "(status <> 4)"
    t.index ["status", "trial_ends_at"], name: "index_subscriptions_on_status_and_trial_ends_at"
  end

  create_table "user_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "permission", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "permission"], name: "index_user_permissions_on_user_id_and_permission", unique: true
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "dismissed_welcome_card", default: false, null: false
    t.string "locale", default: "pt-BR", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.string "cpf_cnpj"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "", null: false
    t.integer "system_role"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "whatsapp_conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.string "customer_name"
    t.string "customer_phone", null: false
    t.datetime "last_message_at"
    t.datetime "session_expires_at"
    t.bigint "space_id", null: false
    t.boolean "unread", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "wa_id", null: false
    t.index ["customer_id"], name: "index_whatsapp_conversations_on_customer_id"
    t.index ["space_id", "wa_id"], name: "index_whatsapp_conversations_on_space_id_and_wa_id", unique: true
    t.index ["space_id"], name: "index_whatsapp_conversations_on_space_id"
  end

  create_table "whatsapp_messages", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "direction", null: false
    t.string "message_type", default: "text", null: false
    t.jsonb "metadata", default: {}
    t.bigint "sent_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "wamid"
    t.bigint "whatsapp_conversation_id", null: false
    t.index ["sent_by_id"], name: "index_whatsapp_messages_on_sent_by_id"
    t.index ["wamid"], name: "index_whatsapp_messages_on_wamid", unique: true, where: "(wamid IS NOT NULL)"
    t.index ["whatsapp_conversation_id"], name: "index_whatsapp_messages_on_whatsapp_conversation_id"
  end

  create_table "whatsapp_phone_numbers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_number", null: false
    t.string "phone_number_id", null: false
    t.string "quality_rating"
    t.bigint "space_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "verified_name"
    t.string "waba_id", null: false
    t.index ["phone_number_id"], name: "index_whatsapp_phone_numbers_on_phone_number_id", unique: true
    t.index ["space_id"], name: "index_whatsapp_phone_numbers_on_space_id", unique: true, where: "(space_id IS NOT NULL)"
  end

  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "spaces"
  add_foreign_key "availability_windows", "availability_schedules"
  add_foreign_key "billing_events", "spaces"
  add_foreign_key "billing_events", "subscriptions"
  add_foreign_key "credit_purchases", "credit_bundles"
  add_foreign_key "credit_purchases", "spaces"
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
  add_foreign_key "subscriptions", "billing_plans"
  add_foreign_key "subscriptions", "billing_plans", column: "pending_billing_plan_id"
  add_foreign_key "subscriptions", "spaces"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "whatsapp_conversations", "customers"
  add_foreign_key "whatsapp_conversations", "spaces"
  add_foreign_key "whatsapp_messages", "users", column: "sent_by_id"
  add_foreign_key "whatsapp_messages", "whatsapp_conversations"
  add_foreign_key "whatsapp_phone_numbers", "spaces"
end
