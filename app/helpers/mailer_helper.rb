module MailerHelper
  EMAIL_THEME = {
    background: "#F8FAFC",
    surface: "#FFFFFF",
    border: "#E2E8F0",
    text: "#0F172A",
    muted: "#475569",
    subtle: "#64748B",
    accent: "#00D2FF",
    cta: "#007AFF",
    cta_text: "#FFFFFF",
    callout_background: "#EFF6FF",
    callout_border: "#BFDBFE",
    success_background: "#ECFDF5",
    success_border: "#A7F3D0",
    warning_background: "#FFF7ED",
    warning_border: "#FED7AA",
    danger_background: "#FEF2F2",
    danger_border: "#FECACA"
  }.freeze

  def email_theme
    EMAIL_THEME
  end

  def email_preheader
    content_for?(:email_preheader) ? content_for(:email_preheader) : default_email_preheader
  end

  def email_eyebrow
    content_for?(:email_eyebrow) ? content_for(:email_eyebrow) : default_email_eyebrow
  end

  def email_title
    content_for?(:email_title) ? content_for(:email_title) : message.subject.to_s
  end

  def email_intro
    content_for?(:email_intro) ? content_for(:email_intro) : nil
  end

  def email_footer_reason
    content_for?(:email_footer_reason) ? content_for(:email_footer_reason) : default_email_footer_reason
  end

  def email_footer_support
    content_for?(:email_footer_support) ? content_for(:email_footer_support) : default_email_footer_support
  end

  def email_signature_name
    content_for?(:email_signature_name) ? content_for(:email_signature_name) : t("layout.app_name")
  end

  def email_cta_label
    content_for?(:email_cta_label) ? content_for(:email_cta_label) : nil
  end

  def email_cta_url
    content_for?(:email_cta_url) ? content_for(:email_cta_url) : nil
  end

  def email_callout_tone
    content_for?(:email_callout_tone) ? content_for(:email_callout_tone) : "info"
  end

  def email_greeting(name = nil)
    return t("billing.payment_mailer.reminder.greeting") if name.blank?

    "#{t('billing.payment_mailer.reminder.greeting').delete(',')} #{name},"
  end

  private

  def default_email_preheader
    case [ current_mailer_name, current_mailer_action ]
    when [ "booking_confirmation_mailer", "customer_confirmation" ]
      t("booking.confirmation_email.intro")
    when [ "billing/payment_mailer", "reminder" ]
      t(
        "billing.payment_mailer.reminder.body_#{@reminder_type}_#{@payment_method}",
        amount: email_money(@amount),
        due_date: email_date(@due_date)
      )
    when [ "billing/subscription_mailer", "plan_change_payment_reminder" ]
      t(
        "billing.subscription_mailer.plan_change_payment_reminder.body_#{@payment_method}",
        plan_name: @new_plan&.name,
        price: email_money(@new_plan&.price_cents.to_f / 100)
      )
    when [ "billing/credits_mailer", "fulfilled" ]
      t("billing.credits_mailer.fulfilled.body", amount: @amount)
    when [ "billing/credits_mailer", "failed" ]
      t("billing.credits_mailer.failed.body", amount: @amount)
    when [ "data_exports/package_mailer", "export_ready" ]
      t("data_exports.package_mailer.export_ready.body")
    when [ "devise/mailer", "confirmation_instructions" ]
      "Confirm your email address to finish setting up your account."
    when [ "devise/mailer", "reset_password_instructions" ]
      "Use the secure link in this email to reset your password."
    when [ "devise/mailer", "unlock_instructions" ]
      "Use the secure link in this email to unlock your account."
    when [ "devise/mailer", "email_changed" ]
      "Your account email address was updated."
    when [ "devise/mailer", "password_change" ]
      "Your account password was changed."
    else
      message.subject.to_s
    end
  end

  def default_email_eyebrow
    case current_mailer_name
    when "booking_confirmation_mailer"
      "Booking"
    when "billing/payment_mailer", "billing/subscription_mailer", "billing/credits_mailer", "billing/chargeback_mailer"
      "Billing"
    when "messaging/customer_message_mailer"
      "Conversation"
    when "data_exports/package_mailer"
      "Account"
    when "devise/mailer"
      "Security"
    else
      t("layout.app_name")
    end
  end

  def default_email_footer_reason
    case [ current_mailer_name, current_mailer_action ]
    when [ "booking_confirmation_mailer", "customer_confirmation" ]
      t("booking.confirmation_email.footer", business_name: @space.name, app_name: t("layout.app_name"))
    when [ "messaging/customer_message_mailer", "customer_message" ]
      "You received this email because a business contacted you through #{t('layout.app_name')}."
    when [ "devise/mailer", "confirmation_instructions" ]
      "You received this email because an account was created with this address."
    when [ "devise/mailer", "reset_password_instructions" ]
      "You received this email because a password reset was requested for your account."
    when [ "devise/mailer", "unlock_instructions" ]
      "You received this email because your account was locked after multiple unsuccessful sign-in attempts."
    when [ "devise/mailer", "email_changed" ]
      "You received this email because your account email address changed."
    when [ "devise/mailer", "password_change" ]
      "You received this email because your account password changed."
    else
      "This is an automated transactional email from #{t('layout.app_name')}."
    end
  end

  def default_email_footer_support
    reply_to = message.reply_to&.first
    return "You can reply directly to this email if you need help." if reply_to.present?

    "Keep this email for your records."
  end

  def email_money(amount)
    number_to_currency(amount, unit: "R$", separator: ",", delimiter: ".")
  end

  def email_date(date)
    date&.strftime("%d/%m/%Y") || "-"
  end

  def current_mailer_name
    controller.class.respond_to?(:mailer_name) ? controller.class.mailer_name.to_s : nil
  end

  def current_mailer_action
    respond_to?(:action_name) ? action_name.to_s : nil
  end
end
