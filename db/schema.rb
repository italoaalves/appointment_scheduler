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

ActiveRecord::Schema[8.1].define(version: 2026_04_17_121500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_deletion_requests", force: :cascade do |t|
    t.datetime "canceled_at"
    t.datetime "completed_at"
    t.string "cpf_cnpj_fingerprint"
    t.datetime "created_at", null: false
    t.string "email_fingerprint"
    t.string "name_fingerprint"
    t.string "phone_fingerprint"
    t.datetime "requested_at", null: false
    t.datetime "scheduled_for", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["completed_at"], name: "index_account_deletion_requests_on_completed_at"
    t.index ["cpf_cnpj_fingerprint"], name: "index_account_deletion_requests_on_cpf_cnpj_fingerprint"
    t.index ["email_fingerprint"], name: "index_account_deletion_requests_on_email_fingerprint"
    t.index ["name_fingerprint"], name: "index_account_deletion_requests_on_name_fingerprint"
    t.index ["phone_fingerprint"], name: "index_account_deletion_requests_on_phone_fingerprint"
    t.index ["status", "scheduled_for"], name: "index_account_deletion_requests_on_status_and_scheduled_for"
    t.index ["user_id"], name: "index_account_deletion_requests_on_pending_user_id", unique: true, where: "(status = 0)"
    t.index ["user_id"], name: "index_account_deletion_requests_on_user_id"
  end

  create_table "appointment_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_label"
    t.string "actor_type", null: false
    t.bigint "appointment_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "idempotency_key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "space_id", null: false
    t.index ["appointment_id"], name: "index_appointment_events_on_appointment_id"
    t.index ["idempotency_key"], name: "index_appointment_events_on_idempotency_key", unique: true
    t.index ["space_id", "appointment_id", "created_at"], name: "idx_appt_events_space_appointment_created_at"
    t.index ["space_id"], name: "index_appointment_events_on_space_id"
  end

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

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "actor_user_id"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.boolean "impersonated", default: false, null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.string "request_id"
    t.bigint "space_id"
    t.string "subject_cpf_cnpj_fingerprint"
    t.string "subject_email_fingerprint"
    t.bigint "subject_id"
    t.string "subject_name_fingerprint"
    t.string "subject_phone_fingerprint"
    t.string "subject_type"
    t.index ["actor_user_id", "created_at"], name: "index_audit_logs_on_actor_user_id_and_created_at"
    t.index ["actor_user_id"], name: "index_audit_logs_on_actor_user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["event_type"], name: "index_audit_logs_on_event_type"
    t.index ["space_id", "created_at"], name: "index_audit_logs_on_space_id_and_created_at"
    t.index ["space_id"], name: "index_audit_logs_on_space_id"
    t.index ["subject_cpf_cnpj_fingerprint"], name: "index_audit_logs_on_subject_cpf_cnpj_fingerprint"
    t.index ["subject_email_fingerprint"], name: "index_audit_logs_on_subject_email_fingerprint"
    t.index ["subject_name_fingerprint"], name: "index_audit_logs_on_subject_name_fingerprint"
    t.index ["subject_phone_fingerprint"], name: "index_audit_logs_on_subject_phone_fingerprint"
    t.index ["subject_type", "subject_id"], name: "index_audit_logs_on_subject_type_and_subject_id"
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

  create_table "backup_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.text "last_error"
    t.datetime "last_failure_at"
    t.string "last_remote_key"
    t.datetime "last_run_finished_at"
    t.datetime "last_run_started_at"
    t.string "last_status"
    t.datetime "last_success_at"
    t.datetime "updated_at", null: false
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

  create_table "conversation_messages", force: :cascade do |t|
    t.text "body"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.integer "credit_cost", default: 0, null: false
    t.integer "direction", null: false
    t.string "external_message_id"
    t.string "message_type", default: "text"
    t.jsonb "metadata", default: {}
    t.bigint "sent_by_id"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_conversation_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_conversation_messages_on_conversation_id"
    t.index ["external_message_id"], name: "index_conversation_messages_on_external_message_id", unique: true, where: "(external_message_id IS NOT NULL)"
    t.index ["sent_by_id"], name: "index_conversation_messages_on_sent_by_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.integer "channel", null: false
    t.string "contact_identifier", null: false
    t.string "contact_name"
    t.datetime "created_at", null: false
    t.integer "credit_cost_total", default: 0, null: false
    t.bigint "customer_id"
    t.string "external_id", null: false
    t.datetime "first_response_at"
    t.datetime "last_message_at"
    t.string "last_message_body"
    t.jsonb "metadata", default: {}
    t.integer "priority", default: 1, null: false
    t.datetime "session_expires_at"
    t.boolean "sla_breached", default: false, null: false
    t.datetime "sla_deadline_at"
    t.bigint "space_id", null: false
    t.integer "status", default: 0, null: false
    t.string "subject"
    t.boolean "unread", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_conversations_on_assigned_to_id"
    t.index ["customer_id"], name: "index_conversations_on_customer_id"
    t.index ["space_id", "assigned_to_id"], name: "index_conversations_on_space_id_and_assigned_to_id", where: "(assigned_to_id IS NOT NULL)"
    t.index ["space_id", "channel", "external_id"], name: "index_conversations_on_space_id_and_channel_and_external_id", unique: true
    t.index ["space_id", "channel"], name: "index_conversations_on_space_id_and_channel"
    t.index ["space_id", "customer_id"], name: "index_conversations_on_space_id_and_customer_id"
    t.index ["space_id", "sla_breached"], name: "index_conversations_on_space_id_and_sla_breached", where: "(sla_breached = true)"
    t.index ["space_id", "status", "last_message_at"], name: "index_conversations_on_space_id_and_status_and_last_message_at"
    t.index ["space_id", "unread"], name: "index_conversations_on_space_id_and_unread", where: "((unread = true) AND (status = ANY (ARRAY[1, 2, 3])))"
    t.index ["space_id"], name: "index_conversations_on_space_id"
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
    t.string "locale"
    t.string "name", null: false
    t.string "phone"
    t.bigint "space_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "whatsapp_opt_in_source"
    t.string "whatsapp_opt_out_source"
    t.datetime "whatsapp_opted_in_at"
    t.datetime "whatsapp_opted_out_at"
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

  create_table "stored_files", force: :cascade do |t|
    t.bigint "attachable_id", null: false
    t.string "attachable_type", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "original_filename", null: false
    t.string "scope", null: false
    t.bigint "space_id"
    t.string "storage_adapter", null: false
    t.string "storage_path", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id", "scope"], name: "idx_on_attachable_type_attachable_id_scope_5b12b85fa5", unique: true
    t.index ["attachable_type", "attachable_id"], name: "index_stored_files_on_attachable"
    t.index ["scope"], name: "index_stored_files_on_scope"
    t.index ["space_id", "scope"], name: "index_stored_files_on_space_id_and_scope"
    t.index ["space_id"], name: "index_stored_files_on_space_id"
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

  create_table "user_identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "email_verified", default: false, null: false
    t.datetime "last_authenticated_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_user_identities_on_provider_and_uid", unique: true
    t.index ["user_id", "provider"], name: "index_user_identities_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identities_on_user_id"
  end

  create_table "user_passkeys", force: :cascade do |t|
    t.boolean "backup_eligible"
    t.boolean "backup_state"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "label", null: false
    t.datetime "last_used_at"
    t.boolean "platform_authenticator", default: false, null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.jsonb "transports", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["external_id"], name: "index_user_passkeys_on_external_id", unique: true
    t.index ["user_id"], name: "index_user_passkeys_on_user_id"
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

  create_table "user_recovery_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["user_id", "used_at"], name: "index_user_recovery_codes_on_user_id_and_used_at"
    t.index ["user_id"], name: "index_user_recovery_codes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.string "cpf_cnpj"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_mfa_at"
    t.datetime "mfa_enabled_at"
    t.string "name"
    t.string "phone_number"
    t.datetime "privacy_policy_accepted_at"
    t.string "privacy_policy_version"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "", null: false
    t.integer "system_role"
    t.datetime "terms_of_service_accepted_at"
    t.string "terms_of_service_version"
    t.integer "totp_consumed_timestep"
    t.datetime "totp_enabled_at"
    t.datetime "totp_last_verified_at"
    t.string "totp_secret"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "webauthn_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
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
    t.jsonb "metadata", default: {}, null: false
    t.string "normalized_phone"
    t.string "phone_number_id", null: false
    t.string "quality_rating"
    t.bigint "space_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "verified_name"
    t.string "waba_id", null: false
    t.index ["normalized_phone"], name: "index_whatsapp_phone_numbers_on_normalized_phone"
    t.index ["phone_number_id"], name: "index_whatsapp_phone_numbers_on_phone_number_id", unique: true
    t.index ["space_id"], name: "index_whatsapp_phone_numbers_on_space_id", unique: true, where: "(space_id IS NOT NULL)"
  end

  add_foreign_key "account_deletion_requests", "users"
  add_foreign_key "appointment_events", "appointments"
  add_foreign_key "appointment_events", "spaces"
  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "spaces"
  add_foreign_key "audit_logs", "spaces"
  add_foreign_key "audit_logs", "users", column: "actor_user_id"
  add_foreign_key "availability_windows", "availability_schedules"
  add_foreign_key "billing_events", "spaces"
  add_foreign_key "billing_events", "subscriptions"
  add_foreign_key "conversation_messages", "conversations"
  add_foreign_key "conversation_messages", "users", column: "sent_by_id"
  add_foreign_key "conversations", "customers"
  add_foreign_key "conversations", "spaces"
  add_foreign_key "conversations", "users", column: "assigned_to_id"
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
  add_foreign_key "stored_files", "spaces"
  add_foreign_key "subscriptions", "billing_plans"
  add_foreign_key "subscriptions", "billing_plans", column: "pending_billing_plan_id"
  add_foreign_key "subscriptions", "spaces"
  add_foreign_key "user_identities", "users"
  add_foreign_key "user_passkeys", "users"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "user_recovery_codes", "users"
  add_foreign_key "whatsapp_conversations", "customers"
  add_foreign_key "whatsapp_conversations", "spaces"
  add_foreign_key "whatsapp_messages", "users", column: "sent_by_id"
  add_foreign_key "whatsapp_messages", "whatsapp_conversations"
  add_foreign_key "whatsapp_phone_numbers", "spaces"
end
